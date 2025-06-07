#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

sleep 90

sudo yum update -y
sudo yum install -y git
sudo amazon-linux-extras install -y nginx1
sudo systemctl enable nginx
sudo systemctl start nginx
sudo amazon-linux-extras install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user
sudo yum install -y python3-pip

# Node.js 16
# curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
# source ~/.nvm/nvm.sh

# # Install Node.js 16
# nvm install 16
# nvm use 16
# nvm alias default 16

# # Verify
# node -v
# npm -v

# SSL/TLS is now handled by ACM at the ALB level

cd /home/ec2-user
sudo git clone https://github.com/syedmominnaqvi/devops-static-site/
sudo chown -R ec2-user:ec2-user devops-static-site
cd /home/ec2-user/devops-static-site/frontend
sudo docker build -t fincard-frontend .
sudo docker run -d -p 9000:80 --name fincard-frontend fincard-frontend

# Configure Nginx as reverse proxy (HTTP only, SSL handled at ALB)
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

# SSL/TLS is now handled by ACM at the ALB level

# Restart nginx to apply configuration
sudo systemctl restart nginx

