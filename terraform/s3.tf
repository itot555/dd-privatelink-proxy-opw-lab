resource "aws_s3_bucket" "app_artifacts" {
  provider = aws.us_east_1
  bucket   = "${local.project_name}-app-artifacts-${data.aws_caller_identity.current.account_id}"

  force_destroy = var.enable_force_destroy

  tags = merge(local.common_tags, { Name = "${local.project_name}-app-artifacts" })
}

resource "aws_s3_bucket_public_access_block" "app_artifacts" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_artifacts" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "app_artifacts" {
  provider = aws.us_east_1
  bucket   = aws_s3_bucket.app_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}
