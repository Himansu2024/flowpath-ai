# infrastructure/terraform/main.tf
# FlowPath AI — AWS Infrastructure
# Provisions: VPC, EC2, RDS PostgreSQL, S3, CloudFront, Lambda, ECR

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "s3" {
    bucket         = "flowpath-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "ap-south-1"
    encrypt        = true
    dynamodb_table = "flowpath-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = { Project = "FlowPath", Environment = var.environment, ManagedBy = "Terraform" } }
}

# ── VPC ──────────────────────────────────────────────────────
resource "aws_vpc" "flowpath" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "flowpath-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.flowpath.id
  tags   = { Name = "flowpath-igw" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.flowpath.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags = { Name = "flowpath-public-a", Tier = "Public" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.flowpath.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
  tags = { Name = "flowpath-public-b", Tier = "Public" }
}

resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.flowpath.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "${var.aws_region}a"
  tags = { Name = "flowpath-private-a", Tier = "Private" }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.flowpath.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}b"
  tags = { Name = "flowpath-private-b", Tier = "Private" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.flowpath.id
  route { cidr_block = "0.0.0.0/0"; gateway_id = aws_internet_gateway.igw.id }
  tags = { Name = "flowpath-public-rt" }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# ── Security Groups ──────────────────────────────────────────
resource "aws_security_group" "backend" {
  name        = "flowpath-backend-sg"
  description = "FlowPath backend API security group"
  vpc_id      = aws_vpc.flowpath.id

  ingress { from_port = 80;   to_port = 80;   protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"]; description = "HTTP" }
  ingress { from_port = 443;  to_port = 443;  protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"]; description = "HTTPS" }
  ingress { from_port = 3000; to_port = 3000; protocol = "tcp"; cidr_blocks = ["10.0.0.0/16"]; description = "API internal" }
  ingress { from_port = 22;   to_port = 22;   protocol = "tcp"; cidr_blocks = [var.admin_ip]; description = "SSH admin" }
  egress  { from_port = 0;    to_port = 0;    protocol = "-1";  cidr_blocks = ["0.0.0.0/0"] }
  tags = { Name = "flowpath-backend-sg" }
}

resource "aws_security_group" "database" {
  name        = "flowpath-db-sg"
  description = "FlowPath RDS PostgreSQL security group"
  vpc_id      = aws_vpc.flowpath.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.backend.id]
    description     = "PostgreSQL from backend only"
  }
  tags = { Name = "flowpath-db-sg" }
}

# ── EC2 — Backend Server ─────────────────────────────────────
resource "aws_key_pair" "flowpath" {
  key_name   = var.key_pair_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "backend" {
  ami                    = var.ubuntu_ami
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  key_name               = aws_key_pair.flowpath.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(<<-INIT
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y docker.io docker-compose-plugin git awscli curl

    # Start Docker
    systemctl enable docker && systemctl start docker
    usermod -aG docker ubuntu

    # Clone repository
    git clone https://github.com/${var.github_org}/flowpath-ai.git /opt/flowpath
    cd /opt/flowpath

    # Login to ECR and start services
    aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin ${aws_ecr_repository.backend.repository_url}

    docker compose -f docker/docker-compose.yml pull
    docker compose -f docker/docker-compose.yml up -d

    echo "FlowPath started at $(date)" >> /var/log/flowpath-init.log
  INIT
  )

  tags = { Name = "flowpath-backend-server" }
}

resource "aws_eip" "backend" {
  instance = aws_instance.backend.id
  domain   = "vpc"
  tags     = { Name = "flowpath-backend-eip" }
}

# ── RDS — PostgreSQL 15 with PostGIS ────────────────────────
resource "aws_db_subnet_group" "flowpath" {
  name       = "flowpath-db-subnet"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags       = { Name = "flowpath-db-subnet-group" }
}

resource "aws_db_instance" "postgres" {
  identifier              = "flowpath-postgres-${var.environment}"
  engine                  = "postgres"
  engine_version          = "15.5"
  instance_class          = "db.t3.small"
  allocated_storage       = 20
  max_allocated_storage   = 100
  storage_encrypted       = true
  storage_type            = "gp3"

  db_name  = "flowpath_db"
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.database.id]
  db_subnet_group_name   = aws_db_subnet_group.flowpath.name

  backup_retention_period    = 7
  backup_window              = "03:00-04:00"
  maintenance_window         = "sun:04:00-sun:05:00"
  skip_final_snapshot        = false
  final_snapshot_identifier  = "flowpath-final-${var.environment}"
  deletion_protection        = var.environment == "production"
  multi_az                   = var.environment == "production"

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn

  tags = { Name = "flowpath-rds" }
}

# ── S3 — Asset Storage ───────────────────────────────────────
resource "aws_s3_bucket" "assets" {
  bucket        = "flowpath-assets-${var.environment}-${data.aws_caller_identity.current.account_id}"
  force_destroy = var.environment != "production"
  tags          = { Name = "flowpath-assets" }
}

resource "aws_s3_bucket_versioning" "assets" {
  bucket = aws_s3_bucket.assets.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "assets" {
  bucket = aws_s3_bucket.assets.id
  rule { apply_server_side_encryption_by_default { sse_algorithm = "AES256" } }
}

# ── ECR — Container Registry ─────────────────────────────────
resource "aws_ecr_repository" "backend" {
  name                 = "flowpath-backend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = { Name = "flowpath-backend-ecr" }
}

resource "aws_ecr_repository" "ai_engine" {
  name                 = "flowpath-ai"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = { Name = "flowpath-ai-ecr" }
}

resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 10 }
      action       = { type = "expire" }
    }]
  })
}

# ── CloudFront CDN ───────────────────────────────────────────
resource "aws_cloudfront_distribution" "api" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "FlowPath API CDN"
  http_version    = "http2and3"

  origin {
    domain_name = aws_eip.backend.public_ip
    origin_id   = "flowpath-api"
    custom_origin_config {
      http_port              = 3000
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["DELETE","GET","HEAD","OPTIONS","PATCH","POST","PUT"]
    cached_methods         = ["GET","HEAD","OPTIONS"]
    target_origin_id       = "flowpath-api"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true
      headers      = ["Authorization","Content-Type","Accept"]
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 0       # No caching for API responses
    max_ttl     = 31536000
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version       = "TLSv1.2_2021"
  }

  tags = { Name = "flowpath-cdn" }
}

# ── Lambda — AI Processing ───────────────────────────────────
resource "aws_lambda_function" "ai_predict" {
  function_name = "flowpath-ai-predict-${var.environment}"
  role          = aws_iam_role.lambda_exec.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.ai_engine.repository_url}:latest"
  timeout       = 30
  memory_size   = 512

  environment {
    variables = {
      DB_HOST     = aws_db_instance.postgres.address
      DB_PORT     = "5432"
      DB_NAME     = "flowpath_db"
      DB_USER     = var.db_username
      DB_PASSWORD = var.db_password
      ENV         = var.environment
    }
  }
  tags = { Name = "flowpath-ai-lambda" }
}

# ── IAM Roles ────────────────────────────────────────────────
resource "aws_iam_role" "ec2_role" {
  name = "flowpath-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow"; Action = "sts:AssumeRole"; Principal = { Service = "ec2.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_ecr" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "flowpath-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_role" "lambda_exec" {
  name = "flowpath-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow"; Action = "sts:AssumeRole"; Principal = { Service = "lambda.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role" "rds_monitoring" {
  name = "flowpath-rds-monitoring"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow"; Action = "sts:AssumeRole"; Principal = { Service = "monitoring.rds.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

data "aws_caller_identity" "current" {}
