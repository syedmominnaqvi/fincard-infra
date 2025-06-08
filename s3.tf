locals {
  script_version = "v1.1.0"  # Increment this version when scripts change
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

# Upload Metabase bootstrap script to S3
resource "aws_s3_object" "metabase_bootstrap" {
  bucket  = aws_s3_bucket.scripts.id
  key     = "metabase_bootstrap.sh"
  source  = "${path.module}/metabase_bootstrap.sh"
  etag    = filemd5("${path.module}/metabase_bootstrap.sh")
  content_type = "text/x-shellscript"
  
  metadata = {
    "version"     = local.script_version
    "description" = "Metabase bootstrap script for EC2 instances"
  }
}

# Upload Nginx configuration for Metabase to S3
resource "aws_s3_object" "nginx_metabase_conf" {
  bucket  = aws_s3_bucket.scripts.id
  key     = "nginx_metabase.conf"
  content = <<-EOF
server {
    listen 80 default_server;
    server_name _;

    # Health check endpoint for ALB
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
        
        proxy_intercept_errors off;
        proxy_redirect off;
    }
}
EOF
  content_type = "text/plain"
  
  metadata = {
    "version"     = local.script_version
    "description" = "Nginx configuration for Metabase"
  }
}