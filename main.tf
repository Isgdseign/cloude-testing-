# Gravia Test Repo - main.tf
# INTENTIONALLY VULNERABLE — For security scanner testing only

terraform {
  required_version = ">= 0.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# VULN: No region specified — could deploy to wrong region
provider "aws" {
  region = "us-east-1"  # Explicitly set region to avoid deploying to unintended regions
}

# VULN: No tags on resources — compliance violation
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

# VULN: Using default route table — no explicit control
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

# VULN: No logging enabled on VPC Flow Logs
# Missing: aws_flow_log resource entirely
resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.flow_log.arn
  log_destination = aws_cloudwatch_log_group.flow_log.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}

# VULN: Hardcoded AMI ID — will break, not dynamic
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux.id  # Dynamic AMI lookup
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id
  key_name      = aws_key_pair.bastion.key_name

  monitoring = true

  iam_instance_profile = aws_iam_instance_profile.bastion.name

  tags = {
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

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

# --- NEW INTENTIONAL VULNERABILITY ---
# VULN: Public S3 bucket (Top-5 cloud security misconfiguration)
# Bucket is world-readable – anyone can list and download objects.
resource "aws_s3_bucket" "public_data" {
  bucket = "gravia-public-data-bucket-${random_id.suffix.hex}"

  tags = {
    Name        = "Public Data Bucket"
    Owner       = "platform-team"
    Environment = "production"
    CostCenter  = "12345"
  }
}

resource "aws_s3_bucket_acl" "public_data" {
  bucket = aws_s3_bucket.public_data.id
  acl    = "private"  # Restricted access via bucket policy
}

resource "aws_s3_bucket_versioning" "public_data" {
  bucket = aws_s3_bucket.public_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_logging" "public_data" {
  bucket = aws_s3_bucket.public_data.id

  target_bucket = aws_s3_bucket.log_bucket.id
  target_prefix = "log/"
}

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
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name = "/aws/vpc/flow-logs"
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
}

resource "random_id" "suffix" {
  byte_length = 4
}
# --- END NEW VULNERABILITY ---

# ----- FIXED SECURITY GROUP EGRESS (only this block changed) -----
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Web server security group"
  vpc_id      = aws_vpc.main.id

  # CRITICAL: 0.0.0.0/0 on all ports (ingress unchanged – not part of this fix)
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # FIXED EGRESS: Now allows only TCP (instead of all protocols)
  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"                # was "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {}
}
# ----------------------------------------------------------------
