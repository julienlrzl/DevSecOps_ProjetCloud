terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─────────────────────────────────────────────────────────────────────────────
# RÉSEAU — VPC multi-couches avec séparation public / privé
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "vpc-dossiers-medicaux-secure" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "igw-secure" }
}

# CORRECTION : subnets publics réservés au Load Balancer uniquement
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "b"}"

  # CORRECTION : pas d'IP publique automatique
  map_public_ip_on_launch = false

  tags = { Name = "subnet-public-${count.index}-secure" }
}

# CORRECTION : subnets privés pour les instances applicatives — pas accessibles depuis Internet
resource "aws_subnet" "private_app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "b"}"

  tags = { Name = "subnet-private-app-${count.index}-secure" }
}

# CORRECTION : subnets isolés pour la base de données — couche réseau dédiée
resource "aws_subnet" "private_db" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_db_subnet_cidrs[count.index]
  availability_zone = "${var.aws_region}${count.index == 0 ? "a" : "b"}"

  tags = { Name = "subnet-private-db-${count.index}-secure" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "rt-public-secure" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# CORRECTION : VPC Endpoints pour SSM — les instances privées communiquent avec AWS
# sans passer par Internet (pas besoin de NAT Gateway ni de SSH)
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "vpce-ssm-secure" }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "vpce-ssmmessages-secure" }
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "vpce-secretsmanager-secure" }
}

# ─────────────────────────────────────────────────────────────────────────────
# SECURITY GROUPS — déclarés sans règles inline pour éviter les cycles
# Les règles sont ajoutées séparément via aws_security_group_rule
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "alb-secure-https-only"
  description = "Load Balancer - HTTPS entrant uniquement"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "sg-alb-secure" }
}

resource "aws_security_group" "ec2_app" {
  name        = "ec2-secure-app"
  description = "EC2 applicatif - trafic depuis ALB seulement, pas de SSH"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "sg-ec2-secure" }
}

resource "aws_security_group" "rds" {
  name        = "rds-secure-private"
  description = "RDS - MySQL depuis EC2 applicatif seulement"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "sg-rds-secure" }
}

resource "aws_security_group" "vpc_endpoints" {
  name        = "vpc-endpoints-secure"
  description = "VPC Endpoints SSM et Secrets Manager"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "sg-vpc-endpoints-secure" }
}

# ─────────────────────────────────────────────────────────────────────────────
# RÈGLES SECURITY GROUPS — séparées pour casser les références circulaires
# ─────────────────────────────────────────────────────────────────────────────

# CORRECTION : ALB — HTTPS entrant depuis Internet uniquement
resource "aws_security_group_rule" "alb_ingress_https" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  description       = "HTTPS depuis Internet"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

# CORRECTION : ALB — sortant vers EC2 sur port 8080 seulement
resource "aws_security_group_rule" "alb_egress_to_ec2" {
  security_group_id        = aws_security_group.alb.id
  type                     = "egress"
  description              = "Trafic vers EC2 applicatif seulement"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2_app.id
}

# CORRECTION : EC2 — entrant depuis ALB sur port 8080 seulement (pas de SSH)
resource "aws_security_group_rule" "ec2_ingress_from_alb" {
  security_group_id        = aws_security_group.ec2_app.id
  type                     = "ingress"
  description              = "Trafic applicatif depuis ALB seulement"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
}

# CORRECTION : EC2 — sortant vers RDS sur port 3306 seulement
resource "aws_security_group_rule" "ec2_egress_to_rds" {
  security_group_id        = aws_security_group.ec2_app.id
  type                     = "egress"
  description              = "MySQL vers RDS seulement"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id
}

# CORRECTION : EC2 — sortant vers VPC Endpoints (SSM, Secrets Manager)
resource "aws_security_group_rule" "ec2_egress_to_endpoints" {
  security_group_id = aws_security_group.ec2_app.id
  type              = "egress"
  description       = "HTTPS vers VPC Endpoints"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
}

# CORRECTION : RDS — entrant depuis EC2 sur port 3306 seulement
resource "aws_security_group_rule" "rds_ingress_from_ec2" {
  security_group_id        = aws_security_group.rds.id
  type                     = "ingress"
  description              = "MySQL depuis EC2 applicatif seulement"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ec2_app.id
}

# VPC Endpoints — entrant HTTPS depuis le VPC
resource "aws_security_group_rule" "endpoints_ingress_https" {
  security_group_id = aws_security_group.vpc_endpoints.id
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
}

# ─────────────────────────────────────────────────────────────────────────────
# KMS — clé de chiffrement dédiée
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_kms_key" "main" {
  description             = "Clé KMS pour chiffrement S3, RDS et EBS — dossiers médicaux"
  deletion_window_in_days = 7
  enable_key_rotation     = true # CORRECTION : rotation automatique annuelle

  tags = { Name = "kms-dossiers-medicaux-secure" }
}

resource "aws_kms_alias" "main" {
  name          = "alias/dossiers-medicaux"
  target_key_id = aws_kms_key.main.key_id
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM — moindre privilège
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "ec2_role" {
  name = "role-ec2-secure"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# CORRECTION : droits minimaux — lecture Secrets Manager + logs + SSM uniquement
resource "aws_iam_role_policy" "ec2_minimal" {
  name = "policy-ec2-minimal-secure"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LectureSecrets"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:${var.aws_region}:*:secret:dossiers-medicaux/*"
      },
      {
        Sid    = "EcritureLogs"
        Effect = "Allow"
        Action = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/dossiers-medicaux/*"
      },
      {
        Sid    = "SSMSessionManager"
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "profile-ec2-secure"
  role = aws_iam_role.ec2_role.name
}

# ─────────────────────────────────────────────────────────────────────────────
# EC2 — dans subnet privé, derrière ALB
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_app[0].id # CORRECTION : subnet privé
  vpc_security_group_ids = [aws_security_group.ec2_app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # CORRECTION : volume EBS chiffré avec KMS
  root_block_device {
    volume_size = 20
    encrypted   = true
    kms_key_id  = aws_kms_key.main.arn
  }

  tags = { Name = "ec2-app-secure" }
}

# CORRECTION : Load Balancer en frontal — l'EC2 n'est jamais exposé directement
resource "aws_lb" "alb" {
  name               = "alb-dossiers-medicaux-secure"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = { Name = "alb-secure" }
}

resource "aws_lb_target_group" "app" {
  name     = "tg-app-secure"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/health"
    port = "8080"
  }
}

resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = aws_instance.app.id
  port             = 8080
}

# ─────────────────────────────────────────────────────────────────────────────
# S3 — privé et chiffré
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "dossiers" {
  bucket = var.s3_bucket_name
  tags   = { Name = "s3-dossiers-medicaux-secure" }
}

# CORRECTION : accès public totalement bloqué
resource "aws_s3_bucket_public_access_block" "dossiers" {
  bucket = aws_s3_bucket.dossiers.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORRECTION : chiffrement SSE-KMS pour tous les objets
resource "aws_s3_bucket_server_side_encryption_configuration" "dossiers" {
  bucket = aws_s3_bucket.dossiers.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
    bucket_key_enabled = true
  }
}

# ─────────────────────────────────────────────────────────────────────────────
# RDS — chiffrée, privée, Multi-AZ
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "rds" {
  name       = "rds-subnet-group-secure"
  subnet_ids = aws_subnet.private_db[*].id # CORRECTION : subnets privés dédiés
}

resource "aws_db_instance" "mysql" {
  identifier        = "rds-dossiers-medicaux-secure"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "dossiers_medicaux"
  username = "admin"
  # CORRECTION : mot de passe injecté depuis Secrets Manager — plus de valeur en clair
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # CORRECTION : RDS non accessible depuis Internet
  publicly_accessible = false

  # CORRECTION : données chiffrées au repos avec KMS
  storage_encrypted = true
  kms_key_id        = aws_kms_key.main.arn

  # CORRECTION : Multi-AZ pour la haute disponibilité
  multi_az = true

  # CORRECTION : sauvegardes automatiques activées (7 jours)
  backup_retention_period = 7

  skip_final_snapshot = true

  tags = { Name = "rds-secure" }
}

# ─────────────────────────────────────────────────────────────────────────────
# CLOUDTRAIL — traçabilité complète de toutes les actions AWS
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "cloudtrail-logs-dossiers-medicaux-secure"
  tags   = { Name = "s3-cloudtrail-secure" }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail_logs" {
  bucket                  = aws_s3_bucket.cloudtrail_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "cloudtrail_logs" {
  bucket = aws_s3_bucket.cloudtrail_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.cloudtrail_logs.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.cloudtrail_logs.arn}/AWSLogs/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# CORRECTION : CloudTrail activé — toutes les actions API AWS sont enregistrées
resource "aws_cloudtrail" "main" {
  name                          = "cloudtrail-dossiers-medicaux-secure"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true # Détecte toute altération des logs

  tags = { Name = "cloudtrail-secure" }

  depends_on = [aws_s3_bucket_policy.cloudtrail_logs]
}
