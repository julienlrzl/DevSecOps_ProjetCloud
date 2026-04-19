variable "aws_region" {
  description = "Région AWS cible"
  type        = string
  default     = "ca-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block du VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs des subnets publics (ALB uniquement) — 2 AZ pour la haute disponibilité"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDRs des subnets privés applicatifs (EC2)"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "CIDRs des subnets privés base de données (RDS)"
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}

variable "ami_id" {
  description = "AMI Amazon Linux 2 pour ca-central-1"
  type        = string
  default     = "ami-0c9bfc21ac5bf10eb"
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t3.micro"
}

variable "s3_bucket_name" {
  description = "Nom du bucket S3 de stockage des dossiers médicaux"
  type        = string
  default     = "dossiers-medicaux-secure"
}

# CORRECTION : plus de mot de passe en clair — les credentials RDS sont dans Secrets Manager
variable "db_secret_name" {
  description = "Nom du secret AWS Secrets Manager contenant les credentials RDS"
  type        = string
  default     = "dossiers-medicaux/rds-credentials"
}
