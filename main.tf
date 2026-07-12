<<<<<<< HEAD
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
  # region not set — uses default or env var, not explicit
}

# VULN: No tags on resources — compliance violation
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {}  # Empty tags — no owner, env, or cost-center
}

# VULN: Using default route table — no explicit control
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {}
}

# VULN: No logging enabled on VPC Flow Logs
# Missing: aws_flow_log resource entirely

# VULN: Hardcoded AMI ID — will break, not dynamic
resource "aws_instance" "bastion" {
  ami           = "ami-0c55b159cbfafe1f0"  # Hardcoded, region-specific
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id

  # VULN: No key_pair specified — can't SSH
  # VULN: No monitoring enabled
  # VULN: No IAM instance profile

  tags = {}
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {}
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {}
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {}
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
=======
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
  # region not set — uses default or env var, not explicit
}

# VULN: No tags on resources — compliance violation
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {}  # Empty tags — no owner, env, or cost-center
}

# VULN: Using default route table — no explicit control
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {}
}

# VULN: No logging enabled on VPC Flow Logs
# Missing: aws_flow_log resource entirely

# VULN: Hardcoded AMI ID — will break, not dynamic
resource "aws_instance" "bastion" {
  ami           = "ami-0c55b159cbfafe1f0"  # Hardcoded, region-specific
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public.id

  # VULN: No key_pair specified — can't SSH
  # VULN: No monitoring enabled
  # VULN: No IAM instance profile

  tags = {}
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {}
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"

  tags = {}
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {}
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
  acl    = "public-read"   # <-- INTENTIONALLY MAKING BUCKET PUBLIC

  tags = {}  # No tags, no logging, no versioning
}

resource "random_id" "suffix" {
  byte_length = 4
}
# --- END NEW VULNERABILITY ---
>>>>>>> 2b082d2 (test: trigger auto-scan)
