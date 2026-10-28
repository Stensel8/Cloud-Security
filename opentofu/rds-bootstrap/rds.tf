terraform {
  # Draait op OpenTofu, niet op HashiCorp Terraform (zie week-1/README.md).
  required_version = ">= 1.13.2"
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

# Let op (zie week-1/README.md): dit script draait op zichzelf, los van main.tf, en zonder remote backend.
# Na het aanmaken van de RDS-instance en het noteren van het endpoint verwijder je de lokale state van dit
# script (inclusief terraform.tfstate, de standaard lokale state-bestandsnaam die OpenTofu ook gebruikt),
# zodat een latere "tofu destroy" op main.tf deze database nooit
# per ongeluk meeneemt.

###################################################
# Create a standard VPC
resource "aws_vpc" "saxit_vpc_db" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "saxit_vpc_db"
  }
}
###################################################
# Create different databasetier subnets spread over 2 different availability zones
resource "aws_subnet" "saxit_subnet_db_1" {
  vpc_id            = aws_vpc.saxit_vpc_db.id
  cidr_block        = "10.1.5.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "saxit_subnet_db_1"
  }
}

resource "aws_subnet" "saxit_subnet_db_2" {
  vpc_id            = aws_vpc.saxit_vpc_db.id
  cidr_block        = "10.1.6.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "saxit_subnet_db_2"
  }
}

resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.saxit_subnet_db_1.id, aws_subnet.saxit_subnet_db_2.id]

  tags = {
    Name = "My DB Subnet Group"
  }
}

###################################################
# Create security group DB
# Week 3 (3.2, microsegmentatie/east-west): was eerst open voor 0.0.0.0/0 (beginsituatie week 1), zodat de
# peering nog niet hoeft te bestaan om te testen. Nu beperkt tot alleen de twee applicationtier-subnets van de
# main-VPC (10.0.3.0/24, 10.0.4.0/24). Geen security-group-referentie naar applicationtier_sg, want die staat in
# een andere (gepeerde) VPC; CIDR's van de applicationtier-subnets zijn hier het betrouwbare alternatief.
resource "aws_security_group" "rdssecuritygroup" {
  name        = "rds_security_group"
  description = "Allow inbound MySQL alleen vanaf de applicationtier, en all outbound traffic"
  vpc_id      = aws_vpc.saxit_vpc_db.id
  tags = {
    Name = "rds_security_group"
  }
  ingress {
    description = "SQL ingress - alleen vanaf de applicationtier-subnets (east-west)"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.3.0/24", "10.0.4.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###################################################
# Create RDS database
resource "aws_db_instance" "cloudsecdb" {
  # identifier = de naam van de RDS-instance zelf (in de console en in iam.tf's data-lookup).
  # db_name = de naam van de database/schema binnen de engine. Allebei "cloudsecdb", maar twee
  # verschillende dingen - vóór provider v5 heette db_name nog "name", wat met v6.70.0 (zie README) niet
  # meer werkt: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/guides/version-5-upgrade
  identifier                          = "cloudsecdb"
  db_name                             = "cloudsecdb"
  allocated_storage                   = 10
  engine                              = "mysql"
  instance_class                      = "db.t3.micro"
  username                            = "admin"
  password                            = "password123" # TODO week 2 (2.1): vervangen door IAM-authenticatie, zie week-2/README.md
  vpc_security_group_ids              = [aws_security_group.rdssecuritygroup.id]
  db_subnet_group_name                = aws_db_subnet_group.my_db_subnet_group.name
  skip_final_snapshot                 = true
  iam_database_authentication_enabled = true # week 2 (2.1): zet de AWSAuthenticationPlugin-route open
}
