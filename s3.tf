locals {
  script_version = "v1.0.0"  # Increment this version when scripts change
}

resource "aws_s3_bucket" "scripts" {
  bucket = "${var.project_name}-scripts-${var.environment}"
  
  tags = {
    Name        = "${var.project_name}-scripts-${var.environment}"
    Environment = var.environment
    Version     = local.script_version
  }
}

# Enable versioning for the S3 bucket
resource "aws_s3_bucket_versioning" "scripts" {
  bucket = aws_s3_bucket.scripts.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Block public access to the bucket
resource "aws_s3_bucket_public_access_block" "scripts" {
  bucket = aws_s3_bucket.scripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload MySQL dummy data SQL script to S3
resource "aws_s3_object" "mysql_dummy_data" {
  bucket  = aws_s3_bucket.scripts.id
  key     = "mysql_dummy_data.sql"
  source  = "${path.module}/scripts/mysql_dummy_data.sql"
  etag    = filemd5("${path.module}/scripts/mysql_dummy_data.sql")
  
  metadata = {
    "version"     = local.script_version
    "description" = "MySQL dummy data for Metabase"
  }
}

# Upload Metabase setup script to S3
resource "aws_s3_object" "metabase_setup" {
  bucket  = aws_s3_bucket.scripts.id
  key     = "setup_metabase.sh"
  source  = "${path.module}/scripts/setup_metabase.sh"
  etag    = filemd5("${path.module}/scripts/setup_metabase.sh")
  content_type = "text/x-shellscript"
  
  metadata = {
    "version"     = local.script_version
    "description" = "Metabase setup automation script"
  }
}

# Upload MySQL loader script to S3
resource "aws_s3_object" "mysql_loader" {
  bucket  = aws_s3_bucket.scripts.id
  key     = "load_mysql_dummy_data.sh"
  source  = "${path.module}/scripts/load_mysql_dummy_data.sh"
  etag    = filemd5("${path.module}/scripts/load_mysql_dummy_data.sh")
  content_type = "text/x-shellscript"
  
  metadata = {
    "version"     = local.script_version
    "description" = "MySQL data loader script"
  }
}