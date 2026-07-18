# Gravia Test Repo - s3-buckets.tf (SECURE)
# All buckets are private, encrypted, versioned, and logged.

# Main data bucket
resource "aws_s3_bucket" "public_data" {
  bucket = "gravia-secure-data-bucket"
  force_destroy = false

  tags = {
    Environment = "production"
  }
}

resource "aws_s3_bucket_public_access_block" "public_data_block" {
  bucket = aws_s3_bucket.public_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "public_data_ver" {
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
  target_bucket = aws_s3_bucket.logs_bucket.id
  target_prefix = "data-access-logs/"
}

# Logs bucket
resource "aws_s3_bucket" "logs_bucket" {
  bucket = "gravia-secure-logs-bucket-2024"
  force_destroy = false

  tags = {
    Environment = "production"
  }
}

resource "aws_s3_bucket_public_access_block" "logs_bucket_block" {
  bucket = aws_s3_bucket.logs_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "logs_bucket_ver" {
  bucket = aws_s3_bucket.logs_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs_bucket_enc" {
  bucket = aws_s3_bucket.logs_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Uploads bucket (sensitive)
resource "aws_s3_bucket" "uploads" {
  bucket = "gravia-secure-uploads-sensitive"
  force_destroy = false

  tags = {
    Environment = "production"
  }
}

resource "aws_s3_bucket_public_access_block" "uploads_block" {
  bucket = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "uploads_ver" {
  bucket = aws_s3_bucket.uploads.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads_enc" {
  bucket = aws_s3_bucket.uploads.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "uploads_log" {
  bucket = aws_s3_bucket.uploads.id
  target_bucket = aws_s3_bucket.logs_bucket.id
  target_prefix = "uploads-access-logs/"
}

resource "aws_s3_bucket_lifecycle_configuration" "uploads_lifecycle" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    id     = "archive-old-files"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }
}
