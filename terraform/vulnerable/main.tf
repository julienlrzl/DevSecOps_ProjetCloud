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
# RÉSEAU
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = { Name = "vpc-dossiers-medicaux-vulnerable" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "igw-vulnerable" }
}

# FAILLE : un seul subnet public — aucune séparation réseau entre les couches
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true # FAILLE : IP publique automatique sur toutes les instances

  tags = { Name = "subnet-public-vulnerable" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "rt-public-vulnerable" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ─────────────────────────────────────────────────────────────────────────────
# SECURITY GROUP
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_security_group" "ec2_open" {
  name        = "ec2-vulnerable-open"
  description = "Security group intentionnellement ouvert - failles de securite"
  vpc_id      = aws_vpc.main.id

  # FAILLE : SSH ouvert à tout Internet — vecteur d'attaque par brute-force ou clé compromise
  ingress {
    description = "SSH depuis tout Internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # FAILLE : HTTP non chiffre accepte directement sur l'instance
  ingress {
    description = "HTTP non chiffre"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # FAILLE : tout le trafic sortant autorisé sans restriction
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "sg-ec2-vulnerable" }
}

# ─────────────────────────────────────────────────────────────────────────────
# IAM
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "ec2_role" {
  name = "role-ec2-vulnerable"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# FAILLE : droits administrateur complets sur l'instance — si l'EC2 est compromise,
# l'attaquant contrôle tout le compte AWS (création d'utilisateurs, suppression de données, etc.)
resource "aws_iam_role_policy_attachment" "admin" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "profile-ec2-vulnerable"
  role = aws_iam_role.ec2_role.name
}

# ─────────────────────────────────────────────────────────────────────────────
# EC2
# ─────────────────────────────────────────────────────────────────────────────

# FAILLE : instance directement dans le subnet public, sans load balancer devant
resource "aws_instance" "app" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ec2_open.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # FAILLE : volume EBS non chiffré — données médicales lisibles si snapshot volé
  root_block_device {
    volume_size = 20
    encrypted   = false
  }

  tags = { Name = "ec2-app-vulnerable" }
}

# ─────────────────────────────────────────────────────────────────────────────
# S3
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "dossiers" {
  bucket = var.s3_bucket_name

  tags = { Name = "s3-dossiers-medicaux-vulnerable" }
}

# FAILLE : accès public non bloqué — les dossiers médicaux peuvent être accessibles depuis Internet
resource "aws_s3_bucket_public_access_block" "dossiers" {
  bucket = aws_s3_bucket.dossiers.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# FAILLE : pas de chiffrement côté serveur — données stockées en clair
# (aucun aws_s3_bucket_server_side_encryption_configuration)

# ─────────────────────────────────────────────────────────────────────────────
# RDS
# ─────────────────────────────────────────────────────────────────────────────

resource "aws_db_subnet_group" "rds" {
  name       = "rds-subnet-group-vulnerable"
  subnet_ids = [aws_subnet.public.id]
  # FAILLE : RDS dans le subnet public (même subnet que l'EC2)
}

resource "aws_security_group" "rds_open" {
  name        = "rds-vulnerable-open"
  description = "RDS accessible depuis tout Internet"
  vpc_id      = aws_vpc.main.id

  # FAILLE : port MySQL ouvert à tout Internet — n'importe qui peut tenter de se connecter
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "mysql" {
  identifier        = "rds-dossiers-medicaux-vulnerable"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "dossiers_medicaux"
  username = var.db_username
  password = var.db_password # FAILLE : mot de passe en clair dans variables.tf

  db_subnet_group_name   = aws_db_subnet_group.rds.name
  vpc_security_group_ids = [aws_security_group.rds_open.id]

  # FAILLE : base de données accessible depuis Internet
  publicly_accessible = true

  # FAILLE : données non chiffrées au repos
  storage_encrypted = false

  # FAILLE : pas de Multi-AZ — indisponibilité totale en cas de panne de zone
  multi_az = false

  # FAILLE : pas de backup automatique
  backup_retention_period = 0

  skip_final_snapshot = true

  tags = { Name = "rds-vulnerable" }
}

# NOTE : CloudTrail absent intentionnellement
# FAILLE : aucune traçabilité des accès — impossible de détecter une intrusion ou de l'auditer
