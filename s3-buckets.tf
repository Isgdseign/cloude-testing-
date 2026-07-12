# Gravia Test Repo - s3-buckets.tf
# INTENTIONALLY VULNERABLE

# VULN: S3 bucket with PUBLIC read access
resource "aws_s3_bucket" "public_data" {
  bucket = "gravia-test-public-data-bucket"

  tags = {}
}

# CRITICAL: Public read ACL — anyone on internet can read
resource "aws_s3_bucket_acl" "public_data_acl" {
  bucket = aws_s3_bucket.public_data.id
  acl    = "public-read"
}

# VULN: No versioning enabled — no recovery from accidental delete
# Missing: aws_s3_bucket_versioning

# VULN: No encryption at rest
# Missing: aws_s3_bucket_server_side_encryption_configuration

# VULN: No logging
# Missing: aws_s3_bucket_logging

# VULN: No bucket policy restricting access
# Missing: aws_s3_bucket_policy with ip restriction


# VULN: Another bucket — also no encryption
resource "aws_s3_bucket" "logs_bucket" {
  bucket = "gravia-test-logs-bucket-2024"

  tags = {}
}

# CRITICAL: Log bucket also public-read
resource "aws_s3_bucket_acl" "logs_acl" {
  bucket = aws_s3_bucket.logs_bucket.id
  acl    = "public-read"
}


# VULN: S3 bucket for sensitive uploads — still public
resource "aws_s3_bucket" "uploads" {
  bucket = "gravia-test-uploads-sensitive"

  tags = {}
}

# CRITICAL: Sensitive uploads bucket publicly readable
resource "aws_s3_bucket_acl" "uploads_acl" {
  bucket = aws_s3_bucket.uploads.id
  acl    = "public-read-write"
}

# VULN: No lifecycle policy — logs grow forever, cost explosion
# Missing: aws_s3_bucket_lifecycle_configuration