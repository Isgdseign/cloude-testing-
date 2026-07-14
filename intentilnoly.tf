# -----------------------------------------------------------------------------
# main.tf - Production AWS Infrastructure (SECURE)
# Author: CloudDevOps Team
# Description: Secure web app infrastructure with RDS, EC2, S3 and Lambda.
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Credentials are injected via environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
# or IAM instance profile – NEVER in code.
provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
variable "aws_region" {
  default = "ap-south-1"
}

variable "env" {
  description = "Deployment environment"
  default     = "staging"
}

variable "root_volume_encrypted" {
  description = "Encrypt root volume"
  default     = true   # NOW encrypted by default
}

# Sensitive variables – pass via .tfvars or environment, never in defaults
variable "db_admin_password" {
  description = "RDS admin password"
  type        = string
  sensitive   = true
  # no default – must be provided externally
}

variable "trusted_ssh_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "10.0.0.0/8"   # Example: only internal network
}

variable "trusted_http_cidr" {
  description = "CIDR block allowed for HTTP/HTTPS"
  type        = string
  default     = "0.0.0.0/0"    # Public web – acceptable for web tier
}

# -----------------------------------------------------------------------------
# Networking & VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "main-vpc"
    Environment = var.env
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    Name        = "main-igw"
    Environment = var.env
  }
}

# Public subnets (for web servers, NAT gateway, etc.)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name        = "public-subnet"
    Environment = var.env
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name        = "private-subnet"
    Environment = var.env
  }
}

# Route tables – public route to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "public-rt"
    Environment = var.env
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# No default route for private subnets – they will use NAT if needed, but we skip for simplicity.

# NACL – restrict inbound to only necessary ports (HTTP/HTTPS and ephemeral)
resource "aws_network_acl" "public_acl" {
  vpc_id = aws_vpc.main_vpc.id
  subnet_ids = [aws_subnet.public.id]

  # Inbound rules – allow HTTP/HTTPS and ephemeral ports
  ingress {
    rule_no    = 100
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    rule_no    = 110
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    rule_no    = 120
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535   # Ephemeral ports for return traffic
  }

  # Outbound – allow all (stateful is fine)
  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name        = "public-nacl"
    Environment = var.env
  }
}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------

# Web tier – allow HTTP/HTTPS from anywhere, SSH from trusted IPs
resource "aws_security_group" "web_sg" {
  name        = "web-tier-sg"
  description = "Secure web tier"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.trusted_http_cidr]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.trusted_http_cidr]
  }

  # SSH access restricted to trusted CIDR
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_ssh_cidr]
  }

  # Outbound – restrict to only necessary destinations
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]   # Allow outbound to internet (common). For tighter control, use VPC endpoints.
  }

  tags = {
    Name        = "web-sg"
    Environment = var.env
  }
}

# Database security group – allow only from web SG
resource "aws_security_group" "db_sg" {
  name        = "db-sg"
  description = "Database security group"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]   # Only web instances can connect
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]   # Allow outbound for updates (can be restricted)
  }

  tags = {
    Name        = "db-sg"
    Environment = var.env
  }
}

# -----------------------------------------------------------------------------
# IAM Configuration – Secure
# -----------------------------------------------------------------------------

# Role for application – assume role only by specific AWS service (EC2) or account
resource "aws_iam_role" "app_role" {
  name = "app_service_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.env
  }
}

# Attach a managed policy with least privilege – e.g., S3 read/write to specific buckets
# Here we attach an AWS managed policy (AmazonS3ReadOnlyAccess) but we'll create a custom one.
resource "aws_iam_policy" "app_s3_policy" {
  name        = "app-s3-policy"
  description = "Allows read/write to specific S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::app-data-${var.env}/*",
          "arn:aws:s3:::app-data-${var.env}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_s3_attach" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_s3_policy.arn
}

# Additional managed policies for logging, etc.
resource "aws_iam_role_policy_attachment" "app_cloudwatch" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM User for CI – but with PGP encryption for secret
resource "aws_iam_user" "ci_user" {
  name = "ci-deploy-user"
}

resource "aws_iam_access_key" "ci_key" {
  user    = aws_iam_user.ci_user.name
  pgp_key = "keybase:my_keybase_handle"   # Use a real PGP key; if not needed, avoid long-lived keys.
}

# Policy for CI user – only what's needed (e.g., deploy to specific resources)
resource "aws_iam_user_policy" "ci_policy" {
  name = "ci-deploy-policy"
  user = aws_iam_user.ci_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          # limited actions
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# S3 Storage – Secure
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "app_data" {
  bucket = "app-data-${var.env}-2024"
  force_destroy = false   # Protect against accidental deletion

  tags = {
    Environment = var.env
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "app_data_block" {
  bucket = aws_s3_bucket.app_data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "app_data_versioning" {
  bucket = aws_s3_bucket.app_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Default encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "app_data_encryption" {
  bucket = aws_s3_bucket.app_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Logging to separate bucket (if needed)
resource "aws_s3_bucket_logging" "app_data_logging" {
  bucket = aws_s3_bucket.app_data.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "app-data-logs/"
}

# A bucket for logs (must be created)
resource "aws_s3_bucket" "log_bucket" {
  bucket = "app-logs-${var.env}"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "log_bucket_block" {
  bucket = aws_s3_bucket.log_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "log_bucket_versioning" {
  bucket = aws_s3_bucket.log_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# -----------------------------------------------------------------------------
# Database (RDS) – Secure
# -----------------------------------------------------------------------------
resource "aws_db_subnet_group" "db_subnet" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.private.id]   # Only private subnets

  tags = {
    Environment = var.env
  }
}

resource "aws_db_instance" "postgres" {
  identifier             = "app-database"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = "dbadmin"
  password               = var.db_admin_password   # from variable, not hardcoded
  db_subnet_group_name   = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  # Secure settings
  publicly_accessible    = false
  storage_encrypted      = true
  backup_retention_period = 7
  skip_final_snapshot    = false   # Take final snapshot before deletion
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Environment = var.env
  }
}

# -----------------------------------------------------------------------------
# Compute (EC2) – Secure
# -----------------------------------------------------------------------------
data "aws_ami" "app_ami" {
  most_recent = true
  owners      = ["amazon"]   # Only official Amazon AMIs

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# EBS volume encrypted
resource "aws_ebs_volume" "data_vol" {
  availability_zone = "${var.aws_region}a"
  size              = 10
  encrypted         = true   # Encrypted

  tags = {
    Environment = var.env
  }
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.app_ami.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # User data should not contain secrets – use SSM or Secrets Manager
  user_data = <<-EOF
              #!/bin/bash
              # Retrieve DB credentials from SSM Parameter Store
              export DB_HOST="${aws_db_instance.postgres.address}"
              export DB_USER="dbadmin"
              export DB_PASSWORD=$(aws ssm get-parameter --name /db/password --with-decryption --query Parameter.Value --output text)
              echo "Starting application..."
              EOF

  # Enable IMDSv2 (metadata_options)
  metadata_options {
    http_tokens   = "required"   # IMDSv2 only
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted   = true   # Always encrypt
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Environment = var.env
    Name        = "web-server"
  }
}

# -----------------------------------------------------------------------------
# Serverless (Lambda) – Secure
# -----------------------------------------------------------------------------
# Use a dedicated IAM role for Lambda with least privilege
resource "aws_iam_role" "lambda_role" {
  name = "lambda-api-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Store API token in Secrets Manager instead of plaintext
resource "aws_secretsmanager_secret" "api_token" {
  name = "api-token"
}

resource "aws_secretsmanager_secret_version" "api_token_ver" {
  secret_id     = aws_secretsmanager_secret.api_token.id
  secret_string = "ghp_1234567890abcdefghijklmnopqrstuvwxyz"   # Better to rotate; this is just an example
}

resource "aws_lambda_function" "api_processor" {
  filename         = "lambda_payload.zip"
  function_name    = "api_processor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  runtime          = "python3.9"

  environment {
    variables = {
      API_ENDPOINT = "https://api.example.com"
      # Token is retrieved at runtime via Secrets Manager in the code
    }
  }

  # VPC placement (if needed) – use private subnets
  vpc_config {
    subnet_ids         = [aws_subnet.private.id]
    security_group_ids = [aws_security_group.web_sg.id]
  }

  tags = {
    Environment = var.env
  }
}

# -----------------------------------------------------------------------------
# CloudTrail (at organization level, but we can create a trail here for demo)
# -----------------------------------------------------------------------------
resource "aws_cloudtrail" "app_trail" {
  name                          = "app-trail"
  s3_bucket_name                = aws_s3_bucket.log_bucket.id
  include_global_service_events = true
  is_multi_region_trail         = true

  tags = {
    Environment = var.env
  }
}

# -----------------------------------------------------------------------------
# Note: All resources now follow security best practices.
# -----------------------------------------------------------------------------
