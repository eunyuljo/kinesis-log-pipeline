# ============================================================
# S3 Bucket for Log Storage
# ============================================================

# S3 버킷 생성 (로그 저장용)
resource "aws_s3_bucket" "log_storage" {
  bucket = "${var.project_name}-${var.environment}-logs-${data.aws_caller_identity.current.account_id}"

  tags = {
    Name        = "${var.project_name}-${var.environment}-logs"
    Description = "Centralized log storage for Kinesis Firehose"
  }
}

# S3 버킷 버저닝 설정
resource "aws_s3_bucket_versioning" "log_storage" {
  bucket = aws_s3_bucket.log_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 버킷 암호화 설정 (AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "log_storage" {
  bucket = aws_s3_bucket.log_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 버킷 퍼블릭 액세스 차단
resource "aws_s3_bucket_public_access_block" "log_storage" {
  bucket = aws_s3_bucket.log_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 버킷 라이프사이클 정책 (로그 보관 기간 설정)
resource "aws_s3_bucket_lifecycle_configuration" "log_storage" {
  bucket = aws_s3_bucket.log_storage.id

  rule {
    id     = "log-retention"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    # 오래된 로그를 Glacier로 이동
    transition {
      days          = 30
      storage_class = "GLACIER"
    }

    # 설정된 기간 후 로그 삭제
    expiration {
      days = var.s3_log_retention_days
    }

    # 이전 버전 로그 정리
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
