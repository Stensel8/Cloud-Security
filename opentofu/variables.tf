# Echte waardes staan in terraform.tfvars (niet gecommit, zie .gitignore en labnotes.txt).
# Zie terraform.tfvars.example voor de vorm.

variable "lab_profile" {
  description = "AWS Academy Learner Lab account-ID, als CLI-profielnaam"
  type        = string
}

variable "sshkey" {
  description = "Naam van de EC2-keypair (zie week-1/README.md)"
  type        = string
}

variable "my_ip" {
  description = "Eigen publieke IP-adres, zonder /32 - enige adres dat met SSH bij de bastion host mag"
  type        = string
}

variable "db_vpc_id" {
  description = "VPC-ID van de db-VPC, output van rds-bootstrap/rds.tf (aws_vpc.saxit_vpc_db.id)"
  type        = string
  default     = ""
}

variable "db_route_table_id" {
  description = "Route table-ID van de db-VPC, bestaat na het draaien van rds-bootstrap/rds.tf"
  type        = string
  default     = ""
}

variable "rds_endpoint" {
  description = "Endpoint van de RDS-instance, output van rds-bootstrap/rds.tf"
  type        = string
  default     = ""
}
