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

variable "public_subnet_cidr" {
  description = "CIDR du subnet public (EC2 exposé directement)"
  type        = string
  default     = "10.0.1.0/24"
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

variable "db_username" {
  description = "Nom d'utilisateur RDS"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Mot de passe RDS — en clair dans les variables (faille intentionnelle)"
  type        = string
  default     = "Password123!"
  # FAILLE : mot de passe en clair dans le code, devrait être dans Secrets Manager
}

variable "s3_bucket_name" {
  description = "Nom du bucket S3 de stockage des dossiers médicaux"
  type        = string
  default     = "dossiers-medicaux-vulnerable"
}
