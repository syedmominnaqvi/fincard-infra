#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Template variables passed from Terraform
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"
AWS_REGION="${aws_region}"
S3_BUCKET="${s3_bucket_name}"
SCRIPT_VERSION="${script_version}"

echo "Starting Metabase instance bootstrap..."
echo "Script version: $SCRIPT_VERSION"

# Install minimal essential packages
echo "Installing essential packages..."
sudo yum update -y
sudo yum install -y git jq awscli
sudo amazon-linux-extras install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

echo "Setting up work directory..."
mkdir -p /home/ec2-user/metabase-setup
cd /home/ec2-user/metabase-setup

# Function to download from S3 with retries
download_from_s3() {
  local source_path="$1"
  local dest_path="$2"
  local max_attempts=5
  local attempt=1
  
  while [ $attempt -le $max_attempts ]; do
    echo "Downloading $source_path (attempt $attempt of $max_attempts)..."
    if aws s3 cp "$source_path" "$dest_path"; then
      echo "Successfully downloaded $source_path"
      return 0
    else
      echo "Failed to download $source_path, retrying in 5 seconds..."
      sleep 5
      attempt=$((attempt+1))
    fi
  done
  
  echo "Failed to download $source_path after $max_attempts attempts."
  return 1
}

# Download and run the bootstrap script
echo "Downloading main bootstrap script from S3..."
download_from_s3 "s3://$S3_BUCKET/metabase_bootstrap.sh" "/home/ec2-user/metabase-setup/metabase_bootstrap.sh" || {
  echo "ERROR: Failed to download bootstrap script. Creating minimal version..."
  
  cat <<'EOF' > /home/ec2-user/metabase-setup/metabase_bootstrap.sh
#!/bin/bash
set -e

# Get environment variables
PROJECT_NAME="$1"
ENVIRONMENT="$2"
AWS_REGION="$3"
S3_BUCKET="$4"
SCRIPT_VERSION="$5"

echo "Running minimal bootstrap script with: PROJECT=$PROJECT_NAME, ENV=$ENVIRONMENT, REGION=$AWS_REGION"

# Install basic packages
sudo amazon-linux-extras install -y nginx1
sudo systemctl enable nginx
sudo systemctl start nginx
sudo yum install -y mariadb postgresql

# Setup minimal Nginx config
cat <<CONF | sudo tee /etc/nginx/conf.d/metabase.conf
server {
    listen 80 default_server;
    server_name _;
    location /health { return 200 'OK'; }
    location / { proxy_pass http://127.0.0.1:3000; }
}
CONF

sudo systemctl restart nginx

# Run minimal Metabase
sudo docker pull metabase/metabase
sudo docker run -d -p 3000:3000 --name metabase \
  -e "MB_DB_TYPE=h2" \
  --restart always \
  metabase/metabase

echo "Minimal bootstrap completed."
EOF

  chmod +x /home/ec2-user/metabase-setup/metabase_bootstrap.sh
}

# Make script executable
chmod +x /home/ec2-user/metabase-setup/metabase_bootstrap.sh

# Execute the bootstrap script with parameters
echo "Executing bootstrap script..."
/home/ec2-user/metabase-setup/metabase_bootstrap.sh "$PROJECT_NAME" "$ENVIRONMENT" "$AWS_REGION" "$S3_BUCKET" "$SCRIPT_VERSION" &

# Write a sentinel file to indicate userdata has completed
echo "EC2 userdata script completed at $(date)" > /home/ec2-user/userdata_complete.txt