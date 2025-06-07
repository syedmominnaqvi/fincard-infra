#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

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
sudo yum install -y mariadb
sudo yum install -y postgresql

# # Node.js 16
# curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
# source ~/.nvm/nvm.sh

# # Install Node.js 16
# nvm install 16
# nvm use 16
# nvm alias default 16

# # Verify
# node -v
# npm -v

# EPEL no longer needed (was used for certbot)

# Certbot no longer needed with ACM

# Generate SSH key for tunneling if it doesn't exist
echo "Setting up SSH keys for tunneling..."
if [ ! -f /home/ec2-user/.ssh/id_rsa ]; then
  sudo mkdir -p /home/ec2-user/.ssh
  sudo ssh-keygen -t rsa -f /home/ec2-user/.ssh/id_rsa -N "" -q
  sudo chown -R ec2-user:ec2-user /home/ec2-user/.ssh
  sudo chmod 700 /home/ec2-user/.ssh
  sudo chmod 600 /home/ec2-user/.ssh/id_rsa
fi

# Add the SSH key to authorized_keys for localhost tunneling
cat /home/ec2-user/.ssh/id_rsa.pub >> /home/ec2-user/.ssh/authorized_keys
sudo chmod 600 /home/ec2-user/.ssh/authorized_keys

# Set up SSH tunnel scripts for database access
cat <<EOF > /home/ec2-user/postgres_tunnel.sh
#!/bin/bash
# Create SSH tunnel to PostgreSQL RDS
# Usage: ./postgres_tunnel.sh start|stop

POSTGRES_HOST="${postgres_host}"
POSTGRES_PORT="${postgres_port}"
LOCAL_PORT="5433" # Local port to forward to

case "\$1" in
  start)
    echo "Starting SSH tunnel to PostgreSQL at \$POSTGRES_HOST:\$POSTGRES_PORT"
    # Check if tunnel is already running
    if pgrep -f "ssh.*\$LOCAL_PORT:\$POSTGRES_HOST:\$POSTGRES_PORT" > /dev/null; then
      echo "Tunnel already running"
      exit 0
    fi
    ssh -i /home/ec2-user/.ssh/id_rsa -f -N -L \$LOCAL_PORT:\$POSTGRES_HOST:\$POSTGRES_PORT ec2-user@localhost -o StrictHostKeyChecking=no
    echo "Tunnel started. Connect to PostgreSQL at localhost:\$LOCAL_PORT"
    ;;
  stop)
    echo "Stopping SSH tunnel to PostgreSQL"
    pkill -f "ssh.*\$LOCAL_PORT:\$POSTGRES_HOST:\$POSTGRES_PORT"
    echo "Tunnel stopped"
    ;;
  *)
    echo "Usage: \$0 start|stop"
    exit 1
    ;;
esac
EOF

cat <<EOF > /home/ec2-user/mysql_tunnel.sh
#!/bin/bash
# Create SSH tunnel to MySQL RDS
# Usage: ./mysql_tunnel.sh start|stop

MYSQL_HOST="${mysql_host}"
MYSQL_PORT="${mysql_port}"
LOCAL_PORT="3307" # Local port to forward to

case "\$1" in
  start)
    echo "Starting SSH tunnel to MySQL at \$MYSQL_HOST:\$MYSQL_PORT"
    # Check if tunnel is already running
    if pgrep -f "ssh.*\$LOCAL_PORT:\$MYSQL_HOST:\$MYSQL_PORT" > /dev/null; then
      echo "Tunnel already running"
      exit 0
    fi
    ssh -i /home/ec2-user/.ssh/id_rsa -f -N -L \$LOCAL_PORT:\$MYSQL_HOST:\$MYSQL_PORT ec2-user@localhost -o StrictHostKeyChecking=no
    echo "Tunnel started. Connect to MySQL at localhost:\$LOCAL_PORT"
    ;;
  stop)
    echo "Stopping SSH tunnel to MySQL"
    pkill -f "ssh.*\$LOCAL_PORT:\$MYSQL_HOST:\$MYSQL_PORT"
    echo "Tunnel stopped"
    ;;
  *)
    echo "Usage: \$0 start|stop"
    exit 1
    ;;
esac
EOF

chmod +x /home/ec2-user/postgres_tunnel.sh
chmod +x /home/ec2-user/mysql_tunnel.sh
chown ec2-user:ec2-user /home/ec2-user/postgres_tunnel.sh
chown ec2-user:ec2-user /home/ec2-user/mysql_tunnel.sh

# Start SSH tunnels automatically
echo "Starting SSH tunnels..."
sudo -u ec2-user /home/ec2-user/postgres_tunnel.sh start
sudo -u ec2-user /home/ec2-user/mysql_tunnel.sh start

# Create Metabase database if it doesn't exist
echo "Setting up Metabase database..."
# PGPASSWORD="${postgres_password}" psql -h localhost -p 5433 -U "${postgres_username}" -d "${postgres_db_name}" -c "CREATE DATABASE metabase;" || echo "Database may already exist, continuing..."

# Deploy Metabase using Docker with tunneled database connections
echo "Starting Metabase container..."
sudo docker run -d -p 3000:3000 --name metabase \
  -e "MB_DB_TYPE=mysql" \
  -e "MB_DB_DBNAME=fincard_mysql" \
  -e "MB_DB_PORT=${mysql_port}" \
  -e "MB_DB_USER=${mysql_username}" \
  -e "MB_DB_PASS=${mysql_password}" \
  -e "MB_DB_HOST=${mysql_host}" \
  --network=host \
  metabase/metabase

# Configure Nginx as reverse proxy with SSL support
echo "Configuring Nginx..."
cat <<EOF | sudo tee /etc/nginx/conf.d/metabase.conf
server {
    listen 80;
    server_name bi.jenkins-devops.store;

    # Health check endpoint for ALB
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        try_files $uri $uri/ =404;
    }
    
}
EOF

# SSL/TLS is now handled by ACM at the ALB level

# Create connection scripts for the databases
cat <<EOF > /home/ec2-user/connect_postgres.sh
#!/bin/bash
# Connect to PostgreSQL database through SSH tunnel
PGPASSWORD=${postgres_password} psql -h localhost -p 5433 -U ${postgres_username} -d ${postgres_db_name}
EOF

cat <<EOF > /home/ec2-user/connect_mysql.sh
#!/bin/bash
# Connect to MySQL database through SSH tunnel
mysql -h localhost -P 3307 -u ${mysql_username} -p${mysql_password} ${mysql_db_name}
EOF

chmod +x /home/ec2-user/connect_postgres.sh
chmod +x /home/ec2-user/connect_mysql.sh
chown ec2-user:ec2-user /home/ec2-user/connect_postgres.sh
chown ec2-user:ec2-user /home/ec2-user/connect_mysql.sh

# Create a cron job to ensure tunnels stay up
echo "*/5 * * * * ec2-user /home/ec2-user/postgres_tunnel.sh start >/dev/null 2>&1" | sudo tee -a /etc/crontab
echo "*/5 * * * * ec2-user /home/ec2-user/mysql_tunnel.sh start >/dev/null 2>&1" | sudo tee -a /etc/crontab

# Restart nginx to apply configuration
echo "Restarting Nginx..."
sudo systemctl restart nginx

# SSL/TLS is now handled by ACM at the ALB level

echo "Metabase instance setup completed!"