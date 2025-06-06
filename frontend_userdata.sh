#!/bin/bash

# Update and install required packages
sudo dnf update -y
sudo dnf install -y git
sudo dnf install -y nginx
sudo dnf install -y docker

# Install Node.js 20.x
sudo dnf install -y nodejs20

# Install Certbot for Let's Encrypt SSL
sudo dnf install -y augeas-libs
sudo python3 -m pip install certbot certbot-nginx

# Configure and start services
sudo mkdir -p /etc/nginx/conf.d
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

# Frontend application setup
cd /home/ec2-user
sudo git clone https://github.com/syedmominnaqvi/devops-static-site/
sudo chown -R ec2-user:ec2-user devops-static-site
cd /home/ec2-user/devops-static-site/frontend
sudo docker build -t fincard-frontend .
sudo docker run -d -p 9000:80 --name fincard-frontend fincard-frontend

# Configure Nginx as reverse proxy with SSL support
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

    # Let's Encrypt ACME challenge directory
    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt;
    }
}
EOF

# Create directory for Let's Encrypt verification
sudo mkdir -p /var/www/letsencrypt
sudo chown -R nginx:nginx /var/www/letsencrypt

# Restart nginx to apply configuration
sudo systemctl restart nginx

# Get SSL certificate using Let's Encrypt
sudo certbot --nginx -d jenkins-devops.store --non-interactive --agree-tos --email momin.naqvi.31515@khi.iba.edu.pk--redirect

# Add cron job to auto-renew certificates
echo "0 0,12 * * * root python3 -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew -q" | sudo tee -a /etc/crontab > /dev/null