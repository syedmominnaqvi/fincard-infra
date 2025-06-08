#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting backend instance setup..."

# Update and install required packages
echo "Updating packages..."
sudo yum update -y
echo "Installing git..."
sudo yum install -y git
echo "Installing nginx..."
sudo amazon-linux-extras install -y nginx1
sudo systemctl enable nginx
sudo systemctl start nginx
echo "Installing docker..."
sudo amazon-linux-extras install -y docker
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

echo "Installing MySQL client (mariadb)..."
sudo yum install -y mariadb

echo "Installing PostgreSQL client..."
sudo amazon-linux-extras enable postgresql14
sudo yum clean metadata
sudo yum install -y postgresql

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

# Backend application setup
cd /home/ec2-user
if [ ! -d devops-static-site ]; then
  sudo git clone https://github.com/syedmominnaqvi/devops-static-site
fi
sudo chown -R ec2-user:ec2-user devops-static-site
cd /home/ec2-user/devops-static-site/backend

echo "Setting up SSH keys for tunneling..."
if [ ! -f /home/ec2-user/.ssh/id_rsa ]; then
  sudo mkdir -p /home/ec2-user/.ssh
  sudo ssh-keygen -t rsa -f /home/ec2-user/.ssh/id_rsa -N "" -q
  sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh
  sudo chmod 700 /home/ec2-user/.ssh
  sudo chmod 600 /home/ec2-user/.ssh/id_rsa
fi
cat /home/ec2-user/.ssh/id_rsa.pub >> /home/ec2-user/.ssh/authorized_keys
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys

echo "Building Docker image..."
sudo docker build -t fincard-backend .

# Set up SSH tunnel scripts for database access
cat <<'EOF' > /home/ec2-user/postgres_tunnel.sh
#!/bin/bash
# Create SSH tunnel to PostgreSQL RDS
# Usage: ./postgres_tunnel.sh start|stop

POSTGRES_HOST="${postgres_host}"
POSTGRES_PORT="${postgres_port}"
LOCAL_PORT="5433" # Local port to forward to

case "$1" in
  start)
    echo "Starting SSH tunnel to PostgreSQL at $POSTGRES_HOST:$POSTGRES_PORT"
    if pgrep -f "ssh.*$LOCAL_PORT:$POSTGRES_HOST:$POSTGRES_PORT" > /dev/null; then
      echo "Tunnel already running"
      exit 0
    fi
    ssh -i /home/ec2-user/.ssh/id_rsa -f -N -L $LOCAL_PORT:$POSTGRES_HOST:$POSTGRES_PORT ec2-user@localhost -o StrictHostKeyChecking=no
    echo "Tunnel started. Connect to PostgreSQL at localhost:$LOCAL_PORT"
    ;;
  stop)
    echo "Stopping SSH tunnel to PostgreSQL"
    pkill -f "ssh.*$LOCAL_PORT:$POSTGRES_HOST:$POSTGRES_PORT"
    echo "Tunnel stopped"
    ;;
  *)
    echo "Usage: $0 start|stop"
    exit 1
    ;;
esac
EOF

cat <<'EOF' > /home/ec2-user/mysql_tunnel.sh
#!/bin/bash
# Create SSH tunnel to MySQL RDS
# Usage: ./mysql_tunnel.sh start|stop

MYSQL_HOST="${mysql_host}"
MYSQL_PORT="${mysql_port}"
LOCAL_PORT="3307" # Local port to forward to

case "$1" in
  start)
    echo "Starting SSH tunnel to MySQL at $MYSQL_HOST:$MYSQL_PORT"
    if pgrep -f "ssh.*$LOCAL_PORT:$MYSQL_HOST:$MYSQL_PORT" > /dev/null; then
      echo "Tunnel already running"
      exit 0
    fi
    ssh -i /home/ec2-user/.ssh/id_rsa -f -N -L $LOCAL_PORT:$MYSQL_HOST:$MYSQL_PORT ec2-user@localhost -o StrictHostKeyChecking=no
    echo "Tunnel started. Connect to MySQL at localhost:$LOCAL_PORT"
    ;;
  stop)
    echo "Stopping SSH tunnel to MySQL"
    pkill -f "ssh.*$LOCAL_PORT:$MYSQL_HOST:$MYSQL_PORT"
    echo "Tunnel stopped"
    ;;
  *)
    echo "Usage: $0 start|stop"
    exit 1
    ;;
esac
EOF

chmod +x /home/ec2-user/postgres_tunnel.sh
chmod +x /home/ec2-user/mysql_tunnel.sh
chown ec2-user:ec2-user /home/ec2-user/postgres_tunnel.sh
chown ec2-user:ec2-user /home/ec2-user/mysql_tunnel.sh

echo "Starting SSH tunnels..."
sudo -u ec2-user /home/ec2-user/postgres_tunnel.sh start
sudo -u ec2-user /home/ec2-user/mysql_tunnel.sh start

# Run the backend container with tunneled database connection
echo "Starting backend container..."
sudo docker run -d -p 5000:5000 --name fincard-backend \
  -e DB_HOST=localhost \
  -e DB_PORT=5433 \
  -e DB_NAME=${postgres_db_name} \
  -e DB_USER=${postgres_username} \
  -e DB_PASSWORD=${postgres_password} \
  --network=host \
  fincard-backend || {
    echo "Backend container may already be running. Attempting to restart..."
    sudo docker rm -f fincard-backend
    sudo docker run -d -p 5000:5000 --name fincard-backend \
      -e DB_HOST=localhost \
      -e DB_PORT=5433 \
      -e DB_NAME=${postgres_db_name} \
      -e DB_USER=${postgres_username} \
      -e DB_PASSWORD=${postgres_password} \
      --network=host \
      fincard-backend
  }

# Configure Nginx as reverse proxy (HTTP only, SSL handled at ALB)
echo "Configuring Nginx..."
cat <<EOF | sudo tee /etc/nginx/conf.d/backend.conf
server {
    listen 80;
    server_name api.jenkins-devops.store;

    # Health check endpoint for ALB
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
}
EOF

# SSL/TLS is now handled by ACM at the ALB level

echo "*/5 * * * * ec2-user /home/ec2-user/postgres_tunnel.sh start >/dev/null 2>&1" | sudo tee -a /etc/crontab
echo "*/5 * * * * ec2-user /home/ec2-user/mysql_tunnel.sh start >/dev/null 2>&1" | sudo tee -a /etc/crontab

echo "Restarting Nginx..."
sudo systemctl restart nginx

# SSL/TLS is now handled by ACM at the ALB level

echo "Backend instance setup completed!"