# Week 2, opdracht 2.1: IAM-authenticatie naar RDS, zodat app01/app02 geen databasewachtwoord meer nodig
# hebben. In het AWS Learner Lab mag een student geen rollen/policies aanmaken (zie week-2/README.md) - deze
# resources zijn dus de beschrijving van wat ik zou aanmaken in een omgeving met voldoende rechten, en falen
# in de Learner Lab met een AccessDenied bij "tofu apply". Dat sluit expliciet aan bij wat de opdracht
# vraagt: de stappen laten zien, ook als de definitieve apply een rode foutmelding geeft.
#
# Dat iam:CreateRole geblokkeerd is, betekent niet dat app01/app02 zonder instance profile moeten draaien: de
# Learner Lab heeft een voorgedefinieerde "LabRole"/"LabInstanceProfile" staan die een student wél aan een
# EC2-instance mag koppelen (geverifieerd met "aws ec2 run-instances --iam-instance-profile
# Name=LabInstanceProfile --dry-run" -> "Request would have succeeded"). Dat is de AWS Academy-manier om
# compute IAM-permissies te geven; main.tf gebruikt daarom onderstaande data-lookup op app01/app02, niet de
# (altijd falende) aws_iam_instance_profile.app_tier_profile hierboven.
data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

resource "aws_iam_role" "app_tier_role" {
  name = "app-tier-rds-iam-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_policy" "rds_connect_policy" {
  name = "app-tier-rds-connect"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "rds-db:connect"
      # cloudsecdb staat in de losse state van rds-bootstrap/ (zie week-1/README.md), dus een "data" lookup
      # op naam in plaats van een directe resource-referentie uit een ander OpenTofu-project.
      Resource = "arn:aws:rds-db:us-east-1:${data.aws_caller_identity.current.account_id}:dbuser:${data.aws_db_instance.cloudsecdb.resource_id}/app_iam_user"
    }]
  })
}

data "aws_db_instance" "cloudsecdb" {
  db_instance_identifier = "cloudsecdb"
}

resource "aws_iam_role_policy_attachment" "app_tier_rds_attach" {
  role       = aws_iam_role.app_tier_role.name
  policy_arn = aws_iam_policy.rds_connect_policy.arn
}

resource "aws_iam_instance_profile" "app_tier_profile" {
  name = "app-tier-instance-profile"
  role = aws_iam_role.app_tier_role.name
}

data "aws_caller_identity" "current" {}

# Op app01/app02 (main.tf) toevoegen: iam_instance_profile = aws_iam_instance_profile.app_tier_profile.name
