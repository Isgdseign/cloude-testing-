# -----------------------------------------------------------------------------
# main.tf - Production AWS Infrastructure
# Author: CloudDevOps Team
# Description: Standard web app infrastructure with RDS, EC2, S3 and Lambda.
# -----------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# V-01: Hardcoded AWS Keys (Base64 encoded to bypass basic regex scanners)
provider "aws" {
  region = var.aws_region
  
  # DevOps team convenience: Encoded keys to avoid plain text in git
  access_key = base64decode("QUPSTDQNW1BSVhBSVhBQ0NFU1M=")
  secret_key = base64decode("czNjcjN0S2V5U2VjcmV0QmFzZTY0RW5jb2RlZA==")
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
variable "aws_region" {
  default = "ap-south-1"
}

variable "env" {
  description = "Deployment environment"
  default     = "staging" # Try changing to prod to see ACL changes
}

variable "root_volume_encrypted" {
  description = "Encrypt root volume"
  default     = false
}

variable "db_admin_password" {
  description = "RDS admin password"
  default     = "Admin123!" # Placeholder, should be overridden
}

# -----------------------------------------------------------------------------
# Networking & VPC
# -----------------------------------------------------------------------------
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
}

# V-20: Network ACL allows 0.0.0.0/0 (Looks like standard SSH/HTTP access)
resource "aws_network_acl_rule" "allow_all_in" {
  network_acl_id = aws_vpc.main_vpc.default_network_acl_id
  rule_number    = 100
  egress         = false
  protocol       = "-1"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 0
  to_port        = 0
}

# -----------------------------------------------------------------------------
# Security Groups (Looks standard, but hides dangerous dynamic rules)
# -----------------------------------------------------------------------------
locals {
  # V-04 & V-05: SSH (22) and All Ports (-1) hidden in a dynamic map
  ingress_rules = {
    ssh_access = { port = 22, protocol = "tcp", cidr = "0.0.0.0/0" }
    internal_app = { port = 0, protocol = "-1", cidr = "0.0.0.0/0" } # Hidden all access
  }
}

resource "aws_security_group" "web_sg" {
  name        = "web-tier-sg"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.main_vpc.id

  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port == 0 ? 0 : ingress.value.port
      protocol    = ingress.value.protocol
      cidr_blocks = [ingress.value.cidr]
    }
  }

  # V-06: Outbound 0.0.0.0/0 all protocols
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------------------------------------------------------
# IAM Configuration
# -----------------------------------------------------------------------------
# V-07: IAM Role Trust Policy Principal = "*" (Looks like a generic cross-account role)
resource "aws_iam_role" "app_role" {
  name = "app_service_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "*" # Wildcard trust
        }
      }
    ]
  })
}

# V-08: IAM Admin access via merge function in non-prod (Bypasses simple policy scanners)
locals {
  base_policy = {
    Version = "2012-10-17"
    Statement = [{
      Action   = ["s3:GetObject", "s3:PutObject"]
      Effect   = "Allow"
      Resource = "*"
    }]
  }
  
  # Dynamic policy merge for dev/staging convenience
  dev_extras = var.env != "prod" ? {
    Statement = [{
      Action   = "*"
      Effect   = "Allow"
      Resource = "*"
    }]
  } : {}

  merged_policy = merge(local.base_policy, local.dev_extras)
}

resource "aws_iam_role_policy" "app_inline" {
  name   = "app_permissions"
  role   = aws_iam_role.app_role.id
  policy = jsonencode(local.merged_policy)
}

# V-09: IAM User with static access keys (No PGP key)
resource "aws_iam_user" "ci_user" {
  name = "ci-deploy-user"
}

resource "aws_iam_access_key" "ci_key" {
  user = aws_iam_user.ci_user.name
  # pgp_key is missing, secret will be in plaintext state file
}

# -----------------------------------------------------------------------------
# S3 Storage
# -----------------------------------------------------------------------------
# V-02: S3 Bucket Public Read conditionally (Looks like a feature flag)
# V-03: S3 force_destroy enabled (Looks useful for ephemeral environments)
resource "aws_s3_bucket" "app_data" {
  bucket = "app-data-${var.env}-2024"
  force_destroy = true
}

resource "aws_s3_bucket_acl" "app_data_acl" {
  bucket = aws_s3_bucket.app_data.id
  acl    = var.env != "prod" ? "public-read" : "private"
}

# -----------------------------------------------------------------------------
# Database (RDS)
# -----------------------------------------------------------------------------
# V-10, V-11, V-12: RDS public, unencrypted, no backups
resource "aws_db_instance" "postgres" {
  identifier             = "app-database"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  username               = "dbadmin"
  password               = var.db_admin_password
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  # Flags that look like dev conveniences but are fatal in prod
  publicly_accessible    = true
  storage_encrypted      = false
  backup_retention_period = 0
  skip_final_snapshot    = true
}

# -----------------------------------------------------------------------------
# Compute (EC2)
# -----------------------------------------------------------------------------
# V-16: AMI Filter with owner "self" and most_recent
data "aws_ami" "app_ami" {
  most_recent = true
  owners      = ["self", "amazon"] # Risky supply chain vector

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# V-19: Standalone EBS Volume unencrypted
resource "aws_ebs_volume" "data_vol" {
  availability_zone = "${var.aws_region}a"
  size              = 10
  encrypted         = false
}

# V-13: EC2 User Data hardcoded DB password
# V-14: EC2 IMDSv1 allowed (metadata_options missing)
# V-15: EC2 Root Volume Unencrypted
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.app_ami.id
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  user_data     = <<-EOF
                  #!/bin/bash
                  # Application setup script
                  export DB_HOST="${aws_db_instance.postgres.address}"
                  export DB_USER="dbadmin"
                  export DB_PASSWORD="SuperSecret123!" # Hardcoded plaintext password
                  echo "Starting application..."
                  EOF
  
  # metadata_options block is intentionally missing, defaulting to IMDSv1

  root_block_device {
    encrypted = var.root_volume_encrypted # defaults to false
    volume_size = 8
  }
}

# -----------------------------------------------------------------------------
# Serverless (Lambda)
# -----------------------------------------------------------------------------
# V-17: Lambda Env Var Plaintext secret
resource "aws_lambda_function" "api_processor" {
  filename         = "lambda_payload.zip"
  function_name    = "api_processor"
  role             = aws_iam_role.app_role.arn
  handler          = "index.handler"
  runtime          = "python3.9"
  
  environment {
    variables = {
      API_ENDPOINT = "https://api.example.com"
      API_TOKEN    = "ghp_1234567890abcdefghijklmnopqrstuvwxyz" # Plaintext secret
    }
  }
}

# -----------------------------------------------------------------------------
# Note: CloudTrail is managed at the Organization level (V-18: Missing CloudTrail)
# -----------------------------------------------------------------------------
