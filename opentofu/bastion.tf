# Week 1, opdracht 1.3: bastion host.
# Enige toegangspunt met SSH tot de presentation- en applicationtier. De security groups van web01/web02/app01/app02
# in main.tf staan SSH alleen nog toe vanaf bastion_sg (security-group-naar-security-group, geen open CIDR meer).

resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "SSH alleen vanaf mijn eigen IP, enige toegangspunt tot de rest van het netwerk"
  vpc_id      = aws_vpc.saxit_vpc.id

  tags = {
    Name = "bastion_sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh_from_my_ip" {
  security_group_id = aws_security_group.bastion_sg.id
  description       = "SSH vanaf mijn eigen IP"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = local.my_ip
}
# Geen IPv6-ingress hier: mijn eigen IPv6-adres staat nergens vastgelegd (labnotes.txt/terraform.tfvars hebben
# alleen var.my_ip, IPv4), dus SSH naar de bastion blijft bewust IPv4-only i.p.v. dat te gokken.

resource "aws_vpc_security_group_egress_rule" "bastion_ssh_to_tiers_ipv4" {
  # Dekt de applicationtier (app01/app02 houden hun IPv4 voor de db-peering, zie main.tf).
  security_group_id = aws_security_group.bastion_sg.id
  description       = "SSH door naar de applicationtier"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.0.0.0/16"
}
resource "aws_vpc_security_group_egress_rule" "bastion_ssh_to_tiers_ipv6" {
  # Dekt de presentationtier (web01/web02 zijn IPv6-only, zie main.tf).
  security_group_id = aws_security_group.bastion_sg.id
  description       = "SSH door naar de presentationtier (IPv6)"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv6         = aws_vpc.saxit_vpc.ipv6_cidr_block
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu_latest.id # zie main.tf
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.saxit_subnet_public_1.id
  associate_public_ip_address = true
  ipv6_address_count          = 1
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = local.sshkey
  root_block_device {
    volume_type = "gp3"
    volume_size = 8
  }

  tags = {
    Name = "bastion"
  }
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_ipv6_address" {
  value = aws_instance.bastion.ipv6_addresses[0]
}
