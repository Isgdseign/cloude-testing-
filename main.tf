# Gravia Test Repo - main.tf (SECURE)
# Now with proper security settings

terraform {
  required_version = ">= 0.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"  # Can be made variable
}

# All resources now have tags for compliance
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

# VPC Flow Logs enabled with proper retention
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id

  tags = {
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

# CloudWatch Log Group with retention
resource "aws_cloudwatch_log_group" "flow_log" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 30   # Added retention

  tags = {
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

resource "aws_iam_role" "flow_log" {
  name = "flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

# Subnets, route tables, etc. (unchanged but with tags)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Bastion instance – now with restricted SSH SG, encrypted root, IMDSv2, etc.
data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

resource "aws_key_pair" "bastion" {
  key_name   = "bastion-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# Security group for bastion – SSH only from trusted IP (example)
resource "aws_security_group" "bastion_sg" {
  name        = "bastion-sg"
  description = "Bastion host security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/16"]   # Restrict to corporate network
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  key_name               = aws_key_pair.bastion.key_name
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
    volume_size = 8
  }

  monitoring = true   # Enable detailed monitoring

  iam_instance_profile = aws_iam_instance_profile.bastion.name

  tags = {
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

resource "aws_iam_instance_profile" "bastion" {
  name = "bastion-instance-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_iam_role" "bastion" {
  name = "bastion-role"

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
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

# S3 bucket – now public access blocked, versioned, encrypted, logged
resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "public_data" {
  bucket = "gravia-public-data-bucket-${random_id.suffix.hex}"
  force_destroy = false

  tags = {
    Name        = "Public Data Bucket"
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

resource "aws_s3_bucket_public_access_block" "public_data_block" {
  bucket = aws_s3_bucket.public_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "public_data" {
  bucket = aws_s3_bucket.public_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "public_data_enc" {
  bucket = aws_s3_bucket.public_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "public_data_log" {
  bucket = aws_s3_bucket.public_data.id
  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "public-data/"
}

# Create a logging bucket (if not already)
resource "aws_s3_bucket" "log_bucket" {
  bucket = "gravia-log-bucket-${random_id.suffix.hex}"
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

resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket_enc" {
  bucket = aws_s3_bucket.log_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
