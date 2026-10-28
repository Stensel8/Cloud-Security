# Week 1, opdracht 1.3: bastion host.
# Enige toegangspunt met SSH tot de presentation- en applicationtier. De security groups van web01/web02/app01/app02
# in main.tf staan SSH alleen nog toe vanaf bastion_sg (security-group-naar-security-group, geen open CIDR meer).

resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "SSH alleen vanaf mijn eigen IP, enige toegangspunt tot de rest van het netwerk"
  vpc_id      = aws_vpc.saxit_vpc.id

  ingress {
    description = "SSH vanaf mijn eigen IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip]
  }

  egress {
    description = "SSH door naar de presentation- en applicationtier"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = {
    Name = "bastion_sg"
  }
}

resource "aws_instance" "bastion" {
  ami                         = "ami-084568db4383264d4" # Amazon Ubuntu Linux 2 AMI
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.saxit_subnet_presentation_1.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = local.sshkey

  tags = {
    Name = "bastion"
  }
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}
