#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Template variables passed from Terraform
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"
AWS_REGION="${aws_region}"

echo "Starting frontend instance setup..."

# Install AWS CLI and jq
echo "Installing required packages..."
sudo yum update -y
sudo yum install -y git jq awscli
sudo amazon-linux-extras install -y nginx1
sudo systemctl enable nginx
sudo systemctl start nginx
sudo amazon-linux-extras install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user
sudo yum install -y python3-pip
echo "Successfully installed required packages."

# Function to get parameter from SSM
get_ssm_parameter() {
  local param_name="/$PROJECT_NAME/$ENVIRONMENT/$1"
  local with_decryption=$2
  
  if [[ "$with_decryption" == "true" ]]; then
    aws ssm get-parameter --name "$param_name" --with-decryption --region "$AWS_REGION" --query "Parameter.Value" --output text
  else
    aws ssm get-parameter --name "$param_name" --region "$AWS_REGION" --query "Parameter.Value" --output text
  fi
}

# Get parameters from SSM
echo "Retrieving configuration from SSM Parameter Store..."
API_URL=$(get_ssm_parameter "api/url" false)
echo "Retrieved API URL from SSM: $API_URL"

echo "Building and running frontend application..."
cd /home/ec2-user
sudo git clone https://github.com/syedmominnaqvi/devops-static-site/
sudo chown -R ec2-user:ec2-user devops-static-site
cd /home/ec2-user/devops-static-site/frontend

# Pass API URL to frontend if needed
# We could modify the Dockerfile or setup an environment file here

sudo docker build -t fincard-frontend .
sudo docker run -d -p 9000:80 --name fincard-frontend fincard-frontend

# Configure Nginx as reverse proxy (HTTP only, SSL handled at ALB)
echo "Configuring Nginx as reverse proxy..."
cat <<EOF | sudo tee /etc/nginx/conf.d/frontend.conf
server {
    listen 80;
    server_name jenkins-devops.store;

    location / {
        proxy_pass http://127.0.0.1:9000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Health check endpoint for ALB
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }
}
EOF

echo "Waiting for frontend container to start..."
sleep 30

# Restart nginx to apply configuration
echo "Restarting Nginx..."
sudo systemctl restart nginx