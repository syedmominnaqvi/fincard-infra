#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

# Template variables passed from Terraform
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"
AWS_REGION="${aws_region}"

echo "Starting backend instance setup..."

# Update and install required packages
echo "Updating packages..."
sudo yum update -y
echo "Installing required packages..."
sudo yum install -y git jq awscli
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

# Get database parameters from SSM
echo "Retrieving database configuration from SSM Parameter Store..."
POSTGRES_HOST=$(get_ssm_parameter "postgres/host" false)
POSTGRES_PORT=$(get_ssm_parameter "postgres/port" false)
POSTGRES_DB=$(get_ssm_parameter "postgres/database" false)
POSTGRES_USER=$(get_ssm_parameter "postgres/username" false)
POSTGRES_PASSWORD=$(get_ssm_parameter "postgres/password" true)

MYSQL_HOST=$(get_ssm_parameter "mysql/host" false)
MYSQL_PORT=$(get_ssm_parameter "mysql/port" false)
MYSQL_DB=$(get_ssm_parameter "mysql/database" false)
MYSQL_USER=$(get_ssm_parameter "mysql/username" false)
MYSQL_PASSWORD=$(get_ssm_parameter "mysql/password" true)

echo "Retrieved database parameters from SSM"

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
cat <<EOF > /home/ec2-user/postgres_tunnel.sh
#!/bin/bash
# Create SSH tunnel to PostgreSQL RDS
# Usage: ./postgres_tunnel.sh start|stop

POSTGRES_HOST="$POSTGRES_HOST"
POSTGRES_PORT="$POSTGRES_PORT"
LOCAL_PORT="5433" # Local port to forward to

case "\$1" in
  start)
    echo "Starting SSH tunnel to PostgreSQL at \$POSTGRES_HOST:\$POSTGRES_PORT"
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

MYSQL_HOST="$MYSQL_HOST"
MYSQL_PORT="$MYSQL_PORT"
LOCAL_PORT="3307" # Local port to forward to

case "\$1" in
  start)
    echo "Starting SSH tunnel to MySQL at \$MYSQL_HOST:\$MYSQL_PORT"
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

echo "Starting SSH tunnels..."
sudo -u ec2-user /home/ec2-user/postgres_tunnel.sh start
sudo -u ec2-user /home/ec2-user/mysql_tunnel.sh start

# Run the backend container with tunneled database connection
echo "Starting backend container..."
sudo docker run -d -p 5000:5000 --name fincard-backend \
  -e DB_HOST=localhost \
  -e DB_PORT=5433 \
  -e DB_NAME="$POSTGRES_DB" \
  -e DB_USER="$POSTGRES_USER" \
  -e DB_PASSWORD="$POSTGRES_PASSWORD" \
  --network=host \
  fincard-backend || {
    echo "Backend container may already be running. Attempting to restart..."
    sudo docker rm -f fincard-backend
    sudo docker run -d -p 5000:5000 --name fincard-backend \
      -e DB_HOST=localhost \
      -e DB_PORT=5433 \
      -e DB_NAME="$POSTGRES_DB" \
      -e DB_USER="$POSTGRES_USER" \
      -e DB_PASSWORD="$POSTGRES_PASSWORD" \
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

echo "*/5 * * * * ec2-user /home/ec2-user/postgres_tunnel.sh start >/dev/null 2>&1" | sudo tee -a /etc/crontab
echo "*/5 * * * * ec2-user /home/ec2-user/mysql_tunnel.sh start >/dev/null 2>&1" | sudo tee -a /etc/crontab

echo "Restarting Nginx..."
sudo systemctl restart nginx

echo "Backend instance setup completed!"