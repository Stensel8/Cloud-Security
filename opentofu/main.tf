terraform {
  # Dit project draait op OpenTofu (zie week-1/README.md), niet op HashiCorp Terraform zelf. Dezelfde
  # "terraform"-block-naam werkt in OpenTofu ook, voor compatibiliteit.
  required_version = ">= 1.13.2"
  backend "s3" {
    bucket  = "REPLACE_WITH_YOUR_TFSTATE_BUCKET" # uit labnotes.txt, zie week-1/README.md
    key     = "opentofu.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.70.0"
    }
  }
}
provider "aws" {
  region  = "us-east-1"
  profile = "REPLACE_WITH_YOUR_LAB_PROFILE" # AWS Academy Learner Lab account-ID, uit labnotes.txt
}
###################################################
# Variabelen
locals {
  sshkey = "REPLACE_WITH_YOUR_KEYPAIR_NAME" # uit labnotes.txt
  # Alleen dit IP-adres mag met SSH bij de bastion host (zie week-1 1.3). Vul in als CIDR, bv. "1.2.3.4/32".
  my_ip = "REPLACE_WITH_YOUR_IP/32"
}
###################################################
# Create a standard VPC
resource "aws_vpc" "saxit_vpc" {
  cidr_block = "10.0.0.0/16"

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
# Create peering with db VPC
# vpc_id van de db-VPC: pas aan na het draaien van rds.tf (zie week-1/README.md, stap "DB-VPC peeren").
resource "aws_vpc_peering_connection" "dbpeer" {
  vpc_id      = aws_vpc.saxit_vpc.id
  peer_vpc_id = "REPLACE_WITH_DB_VPC_ID" # output van rds.tf: aws_vpc.saxit_vpc_db.id
  auto_accept = true
}
###################################################
# Create routing table for presentationtier
resource "aws_route_table" "pres-route" {
  vpc_id = aws_vpc.saxit_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.saxit_gw.id
  }
  route {
    cidr_block                = "10.1.0.0/16"
    vpc_peering_connection_id = aws_vpc_peering_connection.dbpeer.id
  }
  tags = {
    Name = "pres-route"
  }
}
###################################################
# Create routing table for db VPC
# route_table_id: de route table van de db-VPC, bestaat al na het draaien van rds.tf.
resource "aws_route" "dbroute" {
  route_table_id            = "REPLACE_WITH_DB_ROUTE_TABLE_ID" # bestaande route table van de db-VPC
  destination_cidr_block    = "10.0.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.dbpeer.id
}
###################################################
# Create security group for presentationtier
resource "aws_security_group" "presentationtier_sg" {
  name        = "presentationtier_sg"
  description = "Allow HTTP to web servers, SSH alleen vanaf de bastion host"
  vpc_id      = aws_vpc.saxit_vpc.id

  ingress {
    description     = "SSH ingress - alleen vanaf de bastion host (zie week-1 1.3 en bastion.tf)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
  ingress {
    description = "HTTP ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    description = "Allow ping"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
###################################################
# Create security group for applicationtier
resource "aws_security_group" "applicationtier_sg" {
  name        = "applicationtier_sg"
  description = "Allow SSH 8080 to app servers"
  vpc_id      = aws_vpc.saxit_vpc.id

  ingress {
    description     = "SSH ingress - alleen vanaf de bastion host (zie week-1 1.3 en bastion.tf)"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }
  # Week 3 (3.1, north-south segmentatie): was eerst de hele range 80-9000 open voor 0.0.0.0/0
  # (de aangeleverde module-baseline). Nu alleen poort 8080, en alleen vanaf de presentation load balancer.
  ingress {
    description     = "HTTP 8080 ingress - alleen vanaf de presentation tier"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.presentationtier_sg.id]
  }
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    description = "Allow ping"
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
###################################################
# Create different presentationtier subnets spread over 2 different availability zones
resource "aws_subnet" "saxit_subnet_presentation_1" {
  vpc_id                  = aws_vpc.saxit_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = {
    Name = "saxit_subnet_presentation_1"
  }
}

resource "aws_subnet" "saxit_subnet_presentation_2" {
  vpc_id                  = aws_vpc.saxit_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  tags = {
    Name = "saxit_subnet_presentation_2"
  }
}

###################################################
# Create different applicationtier subnets spread over 2 different availability zones
resource "aws_subnet" "saxit_subnet_appl_1" {
  vpc_id            = aws_vpc.saxit_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "saxit_subnet_appl_1"
  }
}

resource "aws_subnet" "saxit_subnet_appl_2" {
  vpc_id            = aws_vpc.saxit_vpc.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "saxit_subnet_appl_2"
  }
}

###################################################
# Connect routing table to presentation subnets
resource "aws_route_table_association" "presentationtier1" {
  subnet_id      = aws_subnet.saxit_subnet_presentation_1.id
  route_table_id = aws_route_table.pres-route.id
}
resource "aws_route_table_association" "presentationtier2" {
  subnet_id      = aws_subnet.saxit_subnet_presentation_2.id
  route_table_id = aws_route_table.pres-route.id
}

###################################################
# Connect routing table to application subnets
resource "aws_route_table_association" "applicationtier1" {
  subnet_id      = aws_subnet.saxit_subnet_appl_1.id
  route_table_id = aws_route_table.pres-route.id
}
resource "aws_route_table_association" "applicationtier2" {
  subnet_id      = aws_subnet.saxit_subnet_appl_2.id
  route_table_id = aws_route_table.pres-route.id
}

##################################################
# Bastion host: zie bastion.tf voor de host zelf en zijn security group.
##################################################
# Create an EC2 #1 instance as frontend
resource "aws_instance" "web01" {
  depends_on                  = [aws_lb.application-lb]
  ami                         = "ami-084568db4383264d4" # Amazon Ubuntu Linux 2 AMI
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.saxit_subnet_presentation_1.id
  associate_public_ip_address = true
  root_block_device {
    volume_type = "gp2"
    volume_size = 50
  }
  vpc_security_group_ids = [aws_security_group.presentationtier_sg.id]
  user_data               = <<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt upgrade -y
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
  sudo apt-get install -y docker-ce
  sudo usermod -aG docker ubuntu
  sudo systemctl enable docker
  sudo systemctl start docker
  # Eigen fork, niet de upstream intro-infra/cloudsec: hierin zitten mijn eigen fixes van voor dit vak.
  git clone https://github.com/Stensel8/Cloud-Security.git
  sudo echo "REACT_APP_API_BASE_URL=http://${aws_lb.application-lb.dns_name}:8080" > /Cloud-Security/frontend/.env
  cd /Cloud-Security/frontend
  sudo docker build -t frontend .
  sudo docker run --restart always -p 80:80 -d frontend
  EOF
  key_name                = local.sshkey
  tags = {
    Name = "web01"
  }
}
##################################################
# Create an EC2 #2 instance as frontend
resource "aws_instance" "web02" {
  depends_on                  = [aws_lb.application-lb]
  ami                         = "ami-084568db4383264d4" # Amazon Ubuntu Linux 2 AMI
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.saxit_subnet_presentation_2.id
  associate_public_ip_address = true
  root_block_device {
    volume_type = "gp2"
    volume_size = 50
  }
  vpc_security_group_ids = [aws_security_group.presentationtier_sg.id]
  user_data               = <<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt upgrade -y
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
  sudo apt-get install -y docker-ce
  sudo usermod -aG docker ubuntu
  sudo systemctl enable docker
  sudo systemctl start docker
  git clone https://github.com/Stensel8/Cloud-Security.git
  sudo echo "REACT_APP_API_BASE_URL=http://${aws_lb.application-lb.dns_name}:8080" > /Cloud-Security/frontend/.env
  cd /Cloud-Security/frontend
  sudo docker build -t frontend .
  sudo docker run --restart always -p 80:80 -d frontend
  EOF
  key_name                = local.sshkey
  tags = {
    Name = "web02"
  }
}
##################################################
# Create an EC2 #1 instance as application
resource "aws_instance" "app01" {
  ami                         = "ami-084568db4383264d4" # Amazon Ubuntu Linux 2 AMI
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.saxit_subnet_appl_1.id
  associate_public_ip_address = true
  root_block_device {
    volume_type = "gp2"
    volume_size = 50
  }
  vpc_security_group_ids = [aws_security_group.applicationtier_sg.id]
  iam_instance_profile    = aws_iam_instance_profile.app_tier_profile.name # week 2 (2.1), zie iam.tf
  # TODO week 2 (2.1): wachtwoord in user_data vervangen door IAM-authenticatie naar RDS, zodat hier geen
  # database-inlognaam/wachtwoord meer in platte tekst staat. Blijft nu bewust zo voor de beginsituatie van week 1.
  user_data = <<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt upgrade -y
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
  sudo apt-get install -y docker-ce
  sudo usermod -aG docker ubuntu
  sudo systemctl enable docker
  sudo systemctl start docker
  git clone https://github.com/Stensel8/Cloud-Security.git
  cd /Cloud-Security/backend
  sudo docker build -t backend .
  sudo docker run --restart always -e SPRING_DATASOURCE_URL=jdbc:mysql://REPLACE_WITH_RDS_ENDPOINT/cloudsecdb -e SPRING_DATASOURCE_USERNAME=admin -e SPRING_DATASOURCE_PASSWORD=password123 -p 8080:8080 -d backend
  EOF
  key_name  = local.sshkey
  tags = {
    Name = "app01"
  }
}
##################################################
# Create an EC2 #2 instance as application
resource "aws_instance" "app02" {
  ami                         = "ami-084568db4383264d4" # Amazon Ubuntu Linux 2 AMI
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.saxit_subnet_appl_2.id
  associate_public_ip_address = true
  root_block_device {
    volume_type = "gp2"
    volume_size = 50
  }
  vpc_security_group_ids = [aws_security_group.applicationtier_sg.id]
  iam_instance_profile    = aws_iam_instance_profile.app_tier_profile.name # week 2 (2.1), zie iam.tf
  # TODO week 2 (2.1): zie app01 hierboven.
  user_data = <<-EOF
  #!/bin/bash
  sudo apt update -y
  sudo apt upgrade -y
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
  sudo apt-get install -y docker-ce
  sudo usermod -aG docker ubuntu
  sudo systemctl enable docker
  sudo systemctl start docker
  git clone https://github.com/Stensel8/Cloud-Security.git
  cd /Cloud-Security/backend
  sudo docker build -t backend .
  sudo docker run --restart always -e SPRING_DATASOURCE_URL=jdbc:mysql://REPLACE_WITH_RDS_ENDPOINT/cloudsecdb -e SPRING_DATASOURCE_USERNAME=admin -e SPRING_DATASOURCE_PASSWORD=password123 -p 8080:8080 -d backend
  EOF
  key_name  = local.sshkey
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
  security_groups            = [aws_security_group.presentationtier_sg.id]
  subnets                    = [aws_subnet.saxit_subnet_presentation_1.id, aws_subnet.saxit_subnet_presentation_2.id]
  enable_deletion_protection = false
}
# Create targetgroup
resource "aws_lb_target_group" "presentation-lb-tg" {
  name        = "presentation-lb-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.saxit_vpc.id
  target_type = "ip"
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
  target_id        = aws_instance.web01.private_ip
}
resource "aws_lb_target_group_attachment" "presentation-attach2" {
  target_group_arn = aws_lb_target_group.presentation-lb-tg.arn
  target_id        = aws_instance.web02.private_ip
}
###################################################
# Create loadbalancer appliction tier
resource "aws_lb" "application-lb" {
  name                       = "application-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.applicationtier_sg.id]
  subnets                    = [aws_subnet.saxit_subnet_appl_1.id, aws_subnet.saxit_subnet_appl_2.id]
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
