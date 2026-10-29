terraform {
  # Dit project draait op OpenTofu (zie week-1/README.md), niet op HashiCorp Terraform zelf. Dezelfde
  # "terraform"-block-naam werkt in OpenTofu ook, voor compatibiliteit.
  required_version = ">= 1.13.2"
  # bucket staat expres niet hier (dat zou het account-ID in de bucketnaam in git zetten). Die komt uit
  # backend.hcl, een lokaal, niet-gecommit bestand: "tofu init -backend-config=backend.hcl". Zie week-1/README.md.
  backend "s3" {
    key     = "opentofu.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.71.0"
    }
  }
}
provider "aws" {
  region  = "us-east-1"
  profile = var.lab_profile
}
###################################################
# Variabelen - echte waardes staan in terraform.tfvars (niet gecommit, zie variables.tf en labnotes.txt)
locals {
  sshkey = var.sshkey
  my_ip  = "${var.my_ip}/32" # alleen dit IP-adres mag met SSH bij de bastion host (zie week-1 1.3)
}
###################################################
# Altijd de laatste Ubuntu 26.04 LTS-build ("resolute", Canonical's officiële account), i.p.v. een AMI-ID die op
# het moment van schrijven bevriest. Gebruikt door alle EC2-instances hieronder en in bastion.tf.
data "aws_ami" "ubuntu_latest" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-resolute-26.04-amd64-server-*"]
  }
}
###################################################
# Create a standard VPC
# Dual-stack: assign_generated_ipv6_cidr_block laat AWS een eigen /56 IPv6-blok toewijzen (Amazon-owned, geen BYOIP
# nodig). De db-VPC (rds-bootstrap/rds.tf) blijft bewust IPv4-only - RDS/MariaDB heeft hier geen IPv6 nodig, en die
# opnieuw aanmaken kost alleen maar tijd (9+ min) zonder functioneel voordeel.
resource "aws_vpc" "saxit_vpc" {
  cidr_block                       = "10.0.0.0/16"
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "saxit_vpc"
  }
}

###################################################
# Create an internetgateway in de VPC
resource "aws_internet_gateway" "saxit_gw" {
  vpc_id = aws_vpc.saxit_vpc.id

  tags = {
    Name = "saxit_gw"
  }
}
###################################################
# Publieke subnets: alleen de load balancers en de bastion host staan hierin (dus met een route rechtstreeks naar
# de internet gateway). De presentation-/applicationtier-subnets hieronder zijn nu écht privé - geen publiek IP
# meer op web01/web02/app01/app02, uitgaand verkeer loopt via de NAT gateway in deze publieke subnets.
resource "aws_subnet" "saxit_subnet_public_1" {
  vpc_id                          = aws_vpc.saxit_vpc.id
  cidr_block                      = "10.0.10.0/24"
  map_public_ip_on_launch         = true
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.saxit_vpc.ipv6_cidr_block, 8, 10)
  assign_ipv6_address_on_creation = true
  availability_zone               = "us-east-1a"
  tags = {
    Name = "saxit_subnet_public_1"
  }
}

resource "aws_subnet" "saxit_subnet_public_2" {
  vpc_id                          = aws_vpc.saxit_vpc.id
  cidr_block                      = "10.0.11.0/24"
  map_public_ip_on_launch         = true
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.saxit_vpc.ipv6_cidr_block, 8, 11)
  assign_ipv6_address_on_creation = true
  availability_zone               = "us-east-1b"
  tags = {
    Name = "saxit_subnet_public_2"
  }
}

resource "aws_route_table" "public-route" {
  vpc_id = aws_vpc.saxit_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.saxit_gw.id
  }
  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.saxit_gw.id
  }
  tags = {
    Name = "public-route"
  }
}

resource "aws_route_table_association" "public1" {
  subnet_id      = aws_subnet.saxit_subnet_public_1.id
  route_table_id = aws_route_table.public-route.id
}
resource "aws_route_table_association" "public2" {
  subnet_id      = aws_subnet.saxit_subnet_public_2.id
  route_table_id = aws_route_table.public-route.id
}

# Egress-only internet gateway voor IPv6-egress (gratis). Oorspronkelijk het plan om web01/web02 vólledig
# IPv6-only te laten draaien zonder NAT gateway (zelfde patroon als NAT64/464XLAT bij mobiele providers) - dat
# liep vast op Docker zelf: "docker build"-stappen draaien in een eigen, geïsoleerde bridge die standaard
# alleen IPv4 NAT doet, los van de host's IPv6. Dus toch een NAT gateway erbij (hieronder) voor een werkend
# IPv4-pad, en beide tiers zijn nu gewoon dual-stack - simpeler, en "alles blijft gewoon werken".
resource "aws_egress_only_internet_gateway" "saxit_eigw" {
  vpc_id = aws_vpc.saxit_vpc.id
  tags = {
    Name = "saxit_eigw"
  }
}

resource "aws_eip" "nat_gw_eip" {
  domain = "vpc"
  tags = {
    Name = "saxit_nat_gw_eip"
  }
}

resource "aws_nat_gateway" "saxit_nat_gw" {
  allocation_id = aws_eip.nat_gw_eip.id
  subnet_id     = aws_subnet.saxit_subnet_public_1.id
  tags = {
    Name = "saxit_nat_gw"
  }
  depends_on = [aws_internet_gateway.saxit_gw]
}
###################################################
# Create peering with db VPC
# vpc_id van de db-VPC: pas aan na het draaien van rds.tf (zie week-1/README.md, stap "DB-VPC peeren").
resource "aws_vpc_peering_connection" "dbpeer" {
  vpc_id      = aws_vpc.saxit_vpc.id
  peer_vpc_id = var.db_vpc_id # output van rds.tf: aws_vpc.saxit_vpc_db.id
  auto_accept = true
}
###################################################
# Routing table voor de presentationtier (web01/web02): dual-stack - IPv4 via de NAT gateway, IPv6 via de
# egress-only gateway.
resource "aws_route_table" "web-route" {
  vpc_id = aws_vpc.saxit_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.saxit_nat_gw.id
  }
  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.saxit_eigw.id
  }
  tags = {
    Name = "web-route"
  }
}
###################################################
# Routing table voor de applicationtier (app01/app02): dual-stack, plus de specifieke route naar de db-VPC (RDS).
resource "aws_route_table" "app-route" {
  vpc_id = aws_vpc.saxit_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.saxit_nat_gw.id
  }
  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.saxit_eigw.id
  }
  route {
    cidr_block                = "10.1.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.dbpeer.id
  }
  tags = {
    Name = "app-route"
  }
}
###################################################
# Create routing table for db VPC
# route_table_id: de route table van de db-VPC, bestaat al na het draaien van rds.tf.
resource "aws_route" "dbroute" {
  route_table_id            = var.db_route_table_id # bestaande route table van de db-VPC
  destination_cidr_block    = "10.0.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.dbpeer.id
}
###################################################
# Create security group for presentationtier
# Regels als losse aws_vpc_security_group_ingress_rule/egress_rule-resources i.p.v. inline ingress/egress-blokken:
# elke regel is dan zijn eigen resource (1 CIDR per regel), dus geen risico meer dat OpenTofu een IPv4- en een
# IPv6-regel met hetzelfde protocol/poort probeert te mergen/dupliceren zoals met de oude inline-blokken gebeurde.
resource "aws_security_group" "presentationtier_sg" {
  name        = "presentationtier_sg"
  description = "Allow HTTP to web servers, SSH alleen vanaf de bastion host"
  vpc_id      = aws_vpc.saxit_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "presentation_ssh_from_bastion" {
  security_group_id            = aws_security_group.presentationtier_sg.id
  description                  = "SSH ingress - alleen vanaf de bastion host (zie week-1 1.3 en bastion.tf)"
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.bastion_sg.id
}
resource "aws_vpc_security_group_ingress_rule" "presentation_http_ipv4" {
  # web01/web02 zijn weer dual-stack (zie de toelichting bij de NAT gateway) - deze regel was tijdens de
  # IPv6-only-poging per ongeluk niet teruggezet (de egress-regel hieronder wel), waardoor de ALB alleen
  # vanaf IPv6-clients bereikbaar was.
  security_group_id = aws_security_group.presentationtier_sg.id
  description       = "HTTP ingress (IPv4)"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}
resource "aws_vpc_security_group_ingress_rule" "presentation_http_ipv6" {
  security_group_id = aws_security_group.presentationtier_sg.id
  description       = "HTTP ingress (IPv6)"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv6         = "::/0"
}
# We hebben geen HTTPS-listener (vraagt een ACM-cert voor een domein dat we niet bezitten - zie
# week-4/README.md voor het acme.sh-plan met een eigen domein, later). Zonder deze regel laat de security
# group poort 443 stil vallen (drop, geen RST) - en moderne Chromium-browsers (Chrome/Brave) proberen sinds
# 2023 bij elke http://-navigatie eerst onzichtbaar https ("HTTPS-Upgrades", geen zichtbare instelling, dus
# niet te verwarren met het expliciete "HTTPS-Only Mode"). Bevestigd via Brave's eigen netlog: drie keer
# expliciet "http://presentation-lb-..." getypt, en alle drie resulteerden in een netwerkrequest naar
# "https://presentation-lb-...". Bij de meeste sites valt die poging binnen milliseconden onzichtbaar terug
# op http, omdat hun server/firewall 443 met een snelle RST weigert. Onze SG liet 443 tot nu toe stil vallen
# (drop i.p.v. reject), dus bleef de onzichtbare https-poging de volle timeout hangen voordat Chromium ooit
# aan een http-fallback toekwam - en dat zag je dan als "de site doet het niet", op elk netwerk, in elke
# Chromium-browser. Met 443 open maar zonder listener erachter stuurt de ALB meteen een RST terug, en lost
# dit zich vanzelf op.
resource "aws_vpc_security_group_ingress_rule" "presentation_https_fastfail_ipv4" {
  security_group_id = aws_security_group.presentationtier_sg.id
  description       = "HTTPS ingress (IPv4) - geen listener, alleen voor snelle RST i.p.v. stille drop"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}
resource "aws_vpc_security_group_ingress_rule" "presentation_https_fastfail_ipv6" {
  security_group_id = aws_security_group.presentationtier_sg.id
  description       = "HTTPS ingress (IPv6) - geen listener, alleen voor snelle RST i.p.v. stille drop"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv6         = "::/0"
}
resource "aws_vpc_security_group_ingress_rule" "presentation_ping_ipv6" {
  security_group_id = aws_security_group.presentationtier_sg.id
  description       = "Allow ping (IPv6)"
  from_port         = 128
  to_port           = 0
  ip_protocol       = "icmpv6"
  cidr_ipv6         = "::/0"
}
resource "aws_vpc_security_group_egress_rule" "presentation_egress_ipv6" {
  security_group_id = aws_security_group.presentationtier_sg.id
  ip_protocol       = "-1"
  cidr_ipv6         = "::/0"
}
resource "aws_vpc_security_group_egress_rule" "presentation_egress_ipv4" {
  # web01/web02 zijn weer dual-stack (zie de toelichting bij de NAT gateway in main.tf) - egress-regel dus terug.
  security_group_id = aws_security_group.presentationtier_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
###################################################
# Create security group for applicationtier
resource "aws_security_group" "applicationtier_sg" {
  name        = "applicationtier_sg"
  description = "Allow SSH 8080 to app servers"
  vpc_id      = aws_vpc.saxit_vpc.id
}

resource "aws_vpc_security_group_ingress_rule" "application_ssh_from_bastion" {
  security_group_id            = aws_security_group.applicationtier_sg.id
  description                  = "SSH ingress - alleen vanaf de bastion host (zie week-1 1.3 en bastion.tf)"
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.bastion_sg.id
}
# Week 3 (3.1, north-south segmentatie): was eerst de hele range 80-9000 open voor 0.0.0.0/0
# (de aangeleverde module-baseline). Nu alleen poort 8080, en alleen via de application load balancer.
# Zelf-referentie (applicationtier_sg i.p.v. presentationtier_sg): de load balancer zelf zit óók in
# applicationtier_sg (zie aws_lb.application-lb), dus verkeer van de LB naar app01/app02 heeft als bron-SG
# applicationtier_sg, niet presentationtier_sg - web01/web02 praten toch nooit rechtstreeks met app01/app02,
# alleen via deze load balancer. Een regel die naar presentationtier_sg verwijst matcht dat verkeer dus nooit,
# en blokkeert zo de load balancer's eigen health checks (symptoom: targets blijven permanent "unhealthy"/
# "Target.Timeout", ook als de applicatie zelf prima draait).
resource "aws_vpc_security_group_ingress_rule" "application_http_from_lb" {
  security_group_id            = aws_security_group.applicationtier_sg.id
  description                  = "HTTP 8080 ingress - alleen van de application load balancer"
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.applicationtier_sg.id
}
# De zelf-referentie hierboven dekt alleen LB-naar-instance-verkeer (en de LB's eigen health checks). De
# frontend (React, draait in de browser van de bezoeker) roept application-lb rechtstreeks aan via
# VITE_API_BASE_URL - geen server-side proxy - dus moet de load balancer zelf ook gewoon publiek bereikbaar
# zijn op 8080. Zonder deze regel komt geen enkele browser ooit bij de API (symptoom: fetch naar de
# application-lb hangt en loopt na enkele tientallen seconden in een timeout, los van CORS).
resource "aws_vpc_security_group_ingress_rule" "application_http_public_ipv4" {
  security_group_id = aws_security_group.applicationtier_sg.id
  description        = "HTTP 8080 ingress (IPv4) - publiek, voor de frontend in de browser"
  from_port          = 8080
  to_port             = 8080
  ip_protocol         = "tcp"
  cidr_ipv4           = "0.0.0.0/0"
}
resource "aws_vpc_security_group_ingress_rule" "application_http_public_ipv6" {
  security_group_id = aws_security_group.applicationtier_sg.id
  description        = "HTTP 8080 ingress (IPv6) - publiek, voor de frontend in de browser"
  from_port          = 8080
  to_port             = 8080
  ip_protocol         = "tcp"
  cidr_ipv6           = "::/0"
}
resource "aws_vpc_security_group_ingress_rule" "application_ping_ipv4" {
  security_group_id = aws_security_group.applicationtier_sg.id
  description       = "Allow ping"
  from_port         = 8
  to_port           = 0
  ip_protocol       = "icmp"
  cidr_ipv4         = "0.0.0.0/0"
}
resource "aws_vpc_security_group_ingress_rule" "application_ping_ipv6" {
  security_group_id = aws_security_group.applicationtier_sg.id
  description       = "Allow ping (IPv6)"
  from_port         = 128
  to_port           = 0
  ip_protocol       = "icmpv6"
  cidr_ipv6         = "::/0"
}
resource "aws_vpc_security_group_egress_rule" "application_egress_ipv4" {
  security_group_id = aws_security_group.applicationtier_sg.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
resource "aws_vpc_security_group_egress_rule" "application_egress_ipv6" {
  security_group_id = aws_security_group.applicationtier_sg.id
  ip_protocol       = "-1"
  cidr_ipv6         = "::/0"
}
###################################################
# Presentationtier-subnets: dual-stack, geen ipv6_native. web01/web02 krijgen dus technisch ook een privé-IPv4
# (onvermijdelijk op een dual-stack subnet), maar die wordt nergens voor gebruikt: web-route hieronder heeft geen
# IPv4-route (geen IGW, geen NAT), dus al het verkeer (ingress via de LB, egress naar internet) loopt over IPv6.
# ipv6_native (een echt IPv4-loze subnet) zou dat niet beter maken, maar forceert wel vervanging van de subnet -
# en een ALB-ENI in de oude subnet liet meer dan een uur niet los, wat het te risicovol/traag maakt voor nu.
resource "aws_subnet" "saxit_subnet_presentation_1" {
  vpc_id                          = aws_vpc.saxit_vpc.id
  cidr_block                      = "10.0.1.0/24"
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.saxit_vpc.ipv6_cidr_block, 8, 1)
  assign_ipv6_address_on_creation = true
  availability_zone               = "us-east-1a"
  tags = {
    Name = "saxit_subnet_presentation_1"
  }
}

resource "aws_subnet" "saxit_subnet_presentation_2" {
  vpc_id                          = aws_vpc.saxit_vpc.id
  cidr_block                      = "10.0.2.0/24"
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.saxit_vpc.ipv6_cidr_block, 8, 2)
  assign_ipv6_address_on_creation = true
  availability_zone               = "us-east-1b"
  tags = {
    Name = "saxit_subnet_presentation_2"
  }
}

###################################################
# Applicationtier-subnets: dual-stack - IPv4 blijft nodig voor de RDS-peering (zie app-route hierboven), IPv6 erbij
# voor internet-egress zonder NAT gateway.
resource "aws_subnet" "saxit_subnet_appl_1" {
  vpc_id                          = aws_vpc.saxit_vpc.id
  cidr_block                      = "10.0.3.0/24"
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.saxit_vpc.ipv6_cidr_block, 8, 3)
  assign_ipv6_address_on_creation = true
  availability_zone               = "us-east-1a"

  tags = {
    Name = "saxit_subnet_appl_1"
  }
}

resource "aws_subnet" "saxit_subnet_appl_2" {
  vpc_id                          = aws_vpc.saxit_vpc.id
  cidr_block                      = "10.0.4.0/24"
  ipv6_cidr_block                 = cidrsubnet(aws_vpc.saxit_vpc.ipv6_cidr_block, 8, 4)
  assign_ipv6_address_on_creation = true
  availability_zone               = "us-east-1b"

  tags = {
    Name = "saxit_subnet_appl_2"
  }
}

###################################################
# Connect routing table to presentation subnets
resource "aws_route_table_association" "presentationtier1" {
  subnet_id      = aws_subnet.saxit_subnet_presentation_1.id
  route_table_id = aws_route_table.web-route.id
}
resource "aws_route_table_association" "presentationtier2" {
  subnet_id      = aws_subnet.saxit_subnet_presentation_2.id
  route_table_id = aws_route_table.web-route.id
}

###################################################
# Connect routing table to application subnets
resource "aws_route_table_association" "applicationtier1" {
  subnet_id      = aws_subnet.saxit_subnet_appl_1.id
  route_table_id = aws_route_table.app-route.id
}
resource "aws_route_table_association" "applicationtier2" {
  subnet_id      = aws_subnet.saxit_subnet_appl_2.id
  route_table_id = aws_route_table.app-route.id
}

##################################################
# Bastion host: zie bastion.tf voor de host zelf en zijn security group.
##################################################
# Create an EC2 #1 instance as frontend
resource "aws_instance" "web01" {
  depends_on                  = [aws_lb.application-lb]
  ami                         = data.aws_ami.ubuntu_latest.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.saxit_subnet_presentation_1.id
  associate_public_ip_address = false # geen publiek IPv4; web-route heeft sowieso geen IPv4-internetroute
  ipv6_address_count          = 1
  root_block_device {
    volume_type = "gp3"
    volume_size = 50
  }
  vpc_security_group_ids = [aws_security_group.presentationtier_sg.id]
  # Niet meer strikt nodig nu de code via de mirror komt i.p.v. S3 (zie user_data), maar laten staan - geen
  # nadeel, en handig als een latere week (6/7, Kinesis e.d.) AWS-API-toegang vanaf web01 nodig heeft.
  iam_instance_profile        = data.aws_iam_instance_profile.lab.name
  user_data_replace_on_change = true # anders draait een gewijzigd script nooit opnieuw (cloud-init draait maar 1x)
  user_data                   = <<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt upgrade -y
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce
  sudo usermod -aG docker ubuntu
  sudo systemctl enable docker
  sudo systemctl start docker
  # Code komt van een IPv6-bereikbare mirror, niet van GitHub: github.com heeft geen IPv6 (geen AAAA-record),
  # en deze instance is bewust IPv6-only (zie main.tf). Gewone HTTPS-download, geen AWS-credentials nodig.
  sudo apt-get install -y unzip
  curl -fsSL "https://repos.codetrunk.eu/Stensel8/Cloud-Security/archive/uitwerkingen.zip" -o /tmp/repo.zip
  unzip -q /tmp/repo.zip -d /tmp/repo-extract
  sudo mv /tmp/repo-extract/cloud-security /Cloud-Security
  rm -rf /tmp/repo.zip /tmp/repo-extract
  cd /Cloud-Security/frontend
  sudo docker build --build-arg "VITE_API_BASE_URL=http://${aws_lb.application-lb.dns_name}:8080" -t frontend .
  sudo docker run --restart always -p 80:80 -d frontend
  EOF
  key_name                    = local.sshkey
  tags = {
    Name = "web01"
  }
}
##################################################
# Create an EC2 #2 instance as frontend
resource "aws_instance" "web02" {
  depends_on                  = [aws_lb.application-lb]
  ami                         = data.aws_ami.ubuntu_latest.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.saxit_subnet_presentation_2.id
  associate_public_ip_address = false
  ipv6_address_count          = 1
  root_block_device {
    volume_type = "gp3"
    volume_size = 50
  }
  vpc_security_group_ids      = [aws_security_group.presentationtier_sg.id]
  iam_instance_profile        = data.aws_iam_instance_profile.lab.name # zie de toelichting bij web01 hierboven
  user_data_replace_on_change = true
  user_data                   = <<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt upgrade -y
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce
  sudo usermod -aG docker ubuntu
  sudo systemctl enable docker
  sudo systemctl start docker
  # Code komt van een IPv6-bereikbare mirror, niet van GitHub (zie de toelichting bij web01 hierboven).
  sudo apt-get install -y unzip
  curl -fsSL "https://repos.codetrunk.eu/Stensel8/Cloud-Security/archive/uitwerkingen.zip" -o /tmp/repo.zip
  unzip -q /tmp/repo.zip -d /tmp/repo-extract
  sudo mv /tmp/repo-extract/cloud-security /Cloud-Security
  rm -rf /tmp/repo.zip /tmp/repo-extract
  cd /Cloud-Security/frontend
  sudo docker build --build-arg "VITE_API_BASE_URL=http://${aws_lb.application-lb.dns_name}:8080" -t frontend .
  sudo docker run --restart always -p 80:80 -d frontend
  EOF
  key_name                    = local.sshkey
  tags = {
    Name = "web02"
  }
}
##################################################
# Create an EC2 #1 instance as application
resource "aws_instance" "app01" {
  ami                         = data.aws_ami.ubuntu_latest.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.saxit_subnet_appl_1.id
  associate_public_ip_address = false
  ipv6_address_count          = 1 # internet-egress (apt/git/docker) loopt via IPv6; IPv4 blijft alleen voor de db-peering
  root_block_device {
    volume_type = "gp3"
    volume_size = 50
  }
  vpc_security_group_ids = [aws_security_group.applicationtier_sg.id]
  # LabInstanceProfile (data-lookup in iam.tf) i.p.v. aws_iam_instance_profile.app_tier_profile: die laatste wordt
  # nooit aangemaakt in de Learner Lab (AccessDenied op iam:CreateRole), maar LabInstanceProfile/LabRole staat al
  # klaar en mag je wel koppelen - zie de toelichting in iam.tf.
  iam_instance_profile = data.aws_iam_instance_profile.lab.name
  # TODO week 2 (2.1): wachtwoord in user_data vervangen door IAM-authenticatie naar RDS, zodat hier geen
  # database-inlognaam/wachtwoord meer in platte tekst staat. Blijft nu bewust zo voor de beginsituatie van week 1.
  user_data_replace_on_change = true
  user_data                   = <<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt upgrade -y
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce
  sudo usermod -aG docker ubuntu
  sudo systemctl enable docker
  sudo systemctl start docker
  # Code komt van een IPv6-bereikbare mirror, niet van GitHub: github.com heeft geen IPv6, en deze instance
  # heeft geen algemene IPv4-internetroute (alleen de db-peering, zie main.tf).
  sudo apt-get install -y unzip
  curl -fsSL "https://repos.codetrunk.eu/Stensel8/Cloud-Security/archive/uitwerkingen.zip" -o /tmp/repo.zip
  unzip -q /tmp/repo.zip -d /tmp/repo-extract
  sudo mv /tmp/repo-extract/cloud-security /Cloud-Security
  rm -rf /tmp/repo.zip /tmp/repo-extract
  cd /Cloud-Security/backend
  sudo docker build -t backend .
  sudo docker run --restart always -e "SPRING_DATASOURCE_URL=jdbc:mariadb://${var.rds_endpoint}/cloudsecdb?sslMode=trust" -e SPRING_DATASOURCE_USERNAME=admin -e SPRING_DATASOURCE_PASSWORD=password123 -p 8080:8080 -d backend
  EOF
  key_name                    = local.sshkey
  tags = {
    Name = "app01"
  }
}
##################################################
# Create an EC2 #2 instance as application
resource "aws_instance" "app02" {
  ami                         = data.aws_ami.ubuntu_latest.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.saxit_subnet_appl_2.id
  associate_public_ip_address = false
  ipv6_address_count          = 1
  root_block_device {
    volume_type = "gp3"
    volume_size = 50
  }
  vpc_security_group_ids = [aws_security_group.applicationtier_sg.id]
  iam_instance_profile   = data.aws_iam_instance_profile.lab.name # zie de toelichting bij app01 hierboven
  # TODO week 2 (2.1): zie app01 hierboven.
  user_data_replace_on_change = true
  user_data                   = <<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt upgrade -y
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -y
  sudo apt-get install -y docker-ce
  sudo usermod -aG docker ubuntu
  sudo systemctl enable docker
  sudo systemctl start docker
  # Code komt van een IPv6-bereikbare mirror, niet van GitHub: zie de toelichting bij app01 hierboven.
  sudo apt-get install -y unzip
  curl -fsSL "https://repos.codetrunk.eu/Stensel8/Cloud-Security/archive/uitwerkingen.zip" -o /tmp/repo.zip
  unzip -q /tmp/repo.zip -d /tmp/repo-extract
  sudo mv /tmp/repo-extract/cloud-security /Cloud-Security
  rm -rf /tmp/repo.zip /tmp/repo-extract
  cd /Cloud-Security/backend
  sudo docker build -t backend .
  sudo docker run --restart always -e "SPRING_DATASOURCE_URL=jdbc:mariadb://${var.rds_endpoint}/cloudsecdb?sslMode=trust" -e SPRING_DATASOURCE_USERNAME=admin -e SPRING_DATASOURCE_PASSWORD=password123 -p 8080:8080 -d backend
  EOF
  key_name                    = local.sshkey
  tags = {
    Name = "app02"
  }
}

###################################################
# Create loadbalancer presentation tier
resource "aws_lb" "presentation-lb" {
  name                       = "presentation-lb"
  internal                   = false
  load_balancer_type         = "application"
  ip_address_type            = "dualstack" # publieke subnets hebben een IPv6-blok; de EC2-instances erachter niet meer
  security_groups            = [aws_security_group.presentationtier_sg.id]
  subnets                    = [aws_subnet.saxit_subnet_public_1.id, aws_subnet.saxit_subnet_public_2.id]
  enable_deletion_protection = false
}
# Create targetgroup
resource "aws_lb_target_group" "presentation-lb-tg" {
  # Naam veranderd (was "presentation-lb-tg") toen deze target group naar IPv6-targets overging: target
  # group-namen moeten uniek zijn, dus de oude (IPv4) en nieuwe (IPv6) kunnen niet tegelijk dezelfde naam dragen
  # tijdens de overgang. create_before_destroy zorgt dat de listener eerst naar de nieuwe wijst voor de oude weg mag.
  name            = "presentation-lb-tg-v6"
  port            = 80
  protocol        = "HTTP"
  vpc_id          = aws_vpc.saxit_vpc.id
  target_type     = "ip"
  ip_address_type = "ipv6" # web01/web02 hebben alleen een IPv6-adres
  lifecycle {
    create_before_destroy = true
  }
  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "5"
    path                = "/"
    unhealthy_threshold = "2"
  }
  depends_on = [aws_lb.presentation-lb]
}
# Create listners
resource "aws_alb_listener" "listener-http" {
  load_balancer_arn = aws_lb.presentation-lb.id
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.presentation-lb-tg.arn
  }
}
# Attach targetgroup to LB
resource "aws_lb_target_group_attachment" "presentation-attach1" {
  target_group_arn = aws_lb_target_group.presentation-lb-tg.arn
  target_id        = aws_instance.web01.ipv6_addresses[0]
}
resource "aws_lb_target_group_attachment" "presentation-attach2" {
  target_group_arn = aws_lb_target_group.presentation-lb-tg.arn
  target_id        = aws_instance.web02.ipv6_addresses[0]
}
###################################################
# Create loadbalancer appliction tier
resource "aws_lb" "application-lb" {
  name                       = "application-lb"
  internal                   = false
  load_balancer_type         = "application"
  ip_address_type            = "dualstack"
  security_groups            = [aws_security_group.applicationtier_sg.id]
  subnets                    = [aws_subnet.saxit_subnet_public_1.id, aws_subnet.saxit_subnet_public_2.id]
  enable_deletion_protection = false
}
# Create targetgroup
resource "aws_lb_target_group" "application-lb-tg" {
  name        = "application-lb-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.saxit_vpc.id
  target_type = "ip"
  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200-499"
    timeout             = "5"
    path                = "/"
    unhealthy_threshold = "2"
  }
  depends_on = [aws_lb.application-lb]
}
# Create listners
resource "aws_alb_listener" "listener-http-appl" {
  load_balancer_arn = aws_lb.application-lb.id
  port              = 8080
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.application-lb-tg.arn
  }
}
# Attach targetgroup to LB
resource "aws_lb_target_group_attachment" "application-attach1" {
  target_group_arn = aws_lb_target_group.application-lb-tg.arn
  target_id        = aws_instance.app01.private_ip
}
resource "aws_lb_target_group_attachment" "application-attach2" {
  target_group_arn = aws_lb_target_group.application-lb-tg.arn
  target_id        = aws_instance.app02.private_ip
}
