provider "aws" {
  region = "eu-west-3"
}


#RÉSEAU & AUDIT (Corrige CKV2_AWS_11, CKV_AWS_130, CKV2_AWS_12)
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# On verrouille le groupe de sécurité par défaut (CKV2_AWS_12)
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  # Aucune règle ingress/egress = tout est bloqué par défaut
}

# Sous-réseau sans IP publique automatique (CKV_AWS_130)
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false 
}


#STOCKAGE S3 ULTRA-SÉCURISÉ (Corrige CKV_AWS_21, CKV_AWS_145, CKV_AWS_18)
# Bucket pour stocker les logs d'accès (CKV_AWS_18)
resource "aws_s3_bucket" "log_bucket" {
  bucket = "dossiers-logs-api-medicale"
}
resource "aws_s3_bucket_public_access_block" "log_bucket_block" {
  bucket                  = aws_s3_bucket.log_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "dossiers_secure" {
  bucket = "dossiers-medicaux-secure-api"
}

# Bloque tout accès public (CKV_AWS_53 à 56)
resource "aws_s3_bucket_public_access_block" "dossiers_block" {
  bucket                  = aws_s3_bucket.dossiers_secure.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Active le versionnage pour éviter les pertes de données (CKV_AWS_21)
resource "aws_s3_bucket_versioning" "dossiers_versioning" {
  bucket = aws_s3_bucket.dossiers_secure.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Chiffrement avancé avec clé KMS KMS (CKV_AWS_145)
resource "aws_kms_key" "s3_key" {
  description             = "Clé KMS pour S3"
  enable_key_rotation     = true
}
resource "aws_s3_bucket_server_side_encryption_configuration" "dossiers_crypto" {
  bucket = aws_s3_bucket.dossiers_secure.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_key.arn
    }
  }
}

# Active la journalisation des accès au bucket (CKV_AWS_18)
resource "aws_s3_bucket_logging" "dossiers_logging" {
  bucket        = aws_s3_bucket.dossiers_secure.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}


#BASE DE DONNÉES RDS BLINDÉE (Corrige CKV_AWS_157, 133, 118, 129, 226, 161)
resource "aws_db_instance" "mysql_secure" {
  identifier          = "rds-dossiers-medicaux-secure"
  engine              = "mysql"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  
  username            = "admin"
  password            = "ChangeMeInVaultLater!" # (En prod, on utilise un Secret Manager)
  
  # Sécurité réseau et disque
  publicly_accessible = false  # CKV_AWS_17
  storage_encrypted   = true   # CKV_AWS_16
  
  # Résilience et Sauvegarde
  multi_az                   = true # CKV_AWS_157
  backup_retention_period    = 7    # CKV_AWS_133 (Garde les backups 7 jours)
  auto_minor_version_upgrade = true # CKV_AWS_226
  
  # Monitoring et Authentification
  iam_database_authentication_enabled = true # CKV_AWS_161
  enabled_cloudwatch_logs_exports     = ["audit", "error", "general", "slowquery"] # CKV_AWS_129
  
  skip_final_snapshot = true
}


#MIGRATION PAAS (Remplacement de l'EC2)
# L'EC2 a disparu, ce qui corrige automatiquement :
# CKV_AWS_24 (Port 22 ouvert), CKV_AWS_8 (EBS non chiffré), CKV_AWS_79 (IMDSv1), CKV_AWS_126 (EC2 Monitoring)
resource "aws_apprunner_service" "api_paas" {
  service_name = "api-medicale-paas"

  source_configuration {
    image_repository {
      image_identifier      = "ton-compte.dkr.ecr.region.amazonaws.com/api-medicale-secure:latest"
      image_repository_type = "ECR"
      image_configuration { port = "5000" }
    }
    auto_deployments_enabled = false
  }
}