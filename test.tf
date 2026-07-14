# test.tf – now secure
resource "aws_s3_bucket" "test_new" {
  bucket = "secure-test-bucket"
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "test_block" {
  bucket = aws_s3_bucket.test_new.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "test_versioning" {
  bucket = aws_s3_bucket.test_new.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "test_encryption" {
  bucket = aws_s3_bucket.test_new.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_logging" "test_logging" {
  bucket = aws_s3_bucket.test_new.id
  target_bucket = aws_s3_bucket.log_bucket.id   # Must exist
  target_prefix = "test-logs/"
}
