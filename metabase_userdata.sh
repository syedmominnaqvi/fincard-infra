#!/bin/bash
set -e
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting Metabase instance bootstrap..."
echo "Script version: ${script_version}"

# Install essential packages
echo "Installing essential packages..."
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
sudo yum install -y jq

# Install MySQL client properly
echo "Installing MySQL client..."
sudo yum install -y mariadb mariadb-devel

# Test MySQL client installation
if ! which mysql > /dev/null 2>&1; then
  echo "WARNING: MySQL client (mysql) not found after installation! Trying alternative method..."
  sudo amazon-linux-extras install -y mariadb10.5
  if ! which mysql > /dev/null 2>&1; then
    echo "ERROR: MySQL client still not available. This will cause issues with database loading."
  else
    echo "MySQL client installed successfully using amazon-linux-extras."
  fi
else
  echo "MySQL client installed successfully."
fi

echo "Installing PostgreSQL client..."
sudo amazon-linux-extras enable postgresql14
sudo yum clean metadata
sudo yum install -y postgresql

# Node.js and certbot no longer needed

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

# Create connection scripts for the databases
cat <<EOF > /home/ec2-user/connect_postgres.sh
#!/bin/bash
# Connect to PostgreSQL database through SSH tunnel
PGPASSWORD=${postgres_password} psql -h localhost -p 5433 -U ${postgres_username} -d ${postgres_db_name}
EOF

cat <<EOF > /home/ec2-user/connect_mysql.sh
#!/bin/bash
# Connect to MySQL database through SSH tunnel
mysql -h localhost -P 3307 -u ${mysql_username} -p${mysql_password} fincard_mysql
EOF

chmod +x /home/ec2-user/connect_postgres.sh
chmod +x /home/ec2-user/connect_mysql.sh
chown ec2-user:ec2-user /home/ec2-user/connect_postgres.sh
chown ec2-user:ec2-user /home/ec2-user/connect_mysql.sh

# Create a cron job to ensure tunnels stay up
echo "*/5 * * * * ec2-user /home/ec2-user/postgres_tunnel.sh start >/dev/null 2>&1" | sudo tee -a /etc/crontab
echo "*/5 * * * * ec2-user /home/ec2-user/mysql_tunnel.sh start >/dev/null 2>&1" | sudo tee -a /etc/crontab

# Download scripts from S3 with retry logic
echo "Downloading scripts from S3..."
S3_BUCKET="${s3_bucket_name}"
SCRIPT_VERSION="${script_version}"

# Function to download a file from S3 with retries
download_from_s3() {
  local source_path="$1"
  local dest_path="$2"
  local max_attempts=5
  local attempt=1
  local success=false
  
  while [ $attempt -le $max_attempts ] && [ "$success" = false ]; do
    echo "Downloading $source_path (attempt $attempt of $max_attempts)..."
    if aws s3 cp "$source_path" "$dest_path"; then
      echo "Successfully downloaded $source_path"
      success=true
    else
      echo "Failed to download $source_path, retrying in 5 seconds..."
      sleep 5
      attempt=$((attempt+1))
    fi
  done
  
  if [ "$success" = false ]; then
    echo "Failed to download $source_path after $max_attempts attempts."
    return 1
  fi
  
  return 0
}

# Download MySQL dummy data
download_from_s3 "s3://$S3_BUCKET/mysql_dummy_data.sql" "/home/ec2-user/mysql_dummy_data.sql" || echo "Warning: Failed to download MySQL dummy data"

# Download loader script
download_from_s3 "s3://$S3_BUCKET/load_mysql_dummy_data.sh" "/home/ec2-user/load_mysql_dummy_data.sh" || echo "Warning: Failed to download MySQL loader script"
if [ -f /home/ec2-user/load_mysql_dummy_data.sh ]; then
  chmod +x /home/ec2-user/load_mysql_dummy_data.sh
  chown ec2-user:ec2-user /home/ec2-user/load_mysql_dummy_data.sh
fi

# Download Metabase setup script
download_from_s3 "s3://$S3_BUCKET/setup_metabase.sh" "/home/ec2-user/setup_metabase.sh" || echo "Warning: Failed to download Metabase setup script"
if [ -f /home/ec2-user/setup_metabase.sh ]; then
  chmod +x /home/ec2-user/setup_metabase.sh
  chown ec2-user:ec2-user /home/ec2-user/setup_metabase.sh
fi

# Configure Nginx as reverse proxy (HTTP only, SSL handled at ALB)
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
    }
}
EOF

# Restart nginx to apply configuration
echo "Restarting Nginx..."
sudo systemctl restart nginx

# Execute the MySQL data loader with environment variables
echo "Loading MySQL dummy data..."
if [ -f /home/ec2-user/load_mysql_dummy_data.sh ]; then
  (
    # Make sure script is executable
    chmod +x /home/ec2-user/load_mysql_dummy_data.sh
    
    # Export all required variables
    export mysql_host="${mysql_host}"
    export mysql_port="${mysql_port}"
    export mysql_username="${mysql_username}"
    export mysql_password="${mysql_password}"
    export s3_bucket="${s3_bucket_name}"
    export script_version="${script_version}"
    
    # Run with error handling
    echo "Executing MySQL data loader script..."
    if ! /home/ec2-user/load_mysql_dummy_data.sh; then
      echo "WARNING: MySQL data loading failed with exit code $?. Continuing with setup, but Metabase may not have sample data."
    else
      echo "MySQL data loading completed successfully."
    fi
  )
else
  echo "MySQL loader script not found at /home/ec2-user/load_mysql_dummy_data.sh"
  echo "Attempting to download it directly..."
  
  # Try to download directly
  if aws s3 cp s3://${s3_bucket_name}/load_mysql_dummy_data.sh /home/ec2-user/load_mysql_dummy_data.sh; then
    chmod +x /home/ec2-user/load_mysql_dummy_data.sh
    echo "Downloaded loader script. Attempting to run it..."
    
    (
      export mysql_host="${mysql_host}"
      export mysql_port="${mysql_port}"
      export mysql_username="${mysql_username}"
      export mysql_password="${mysql_password}"
      export s3_bucket="${s3_bucket_name}"
      export script_version="${script_version}"
      
      if ! /home/ec2-user/load_mysql_dummy_data.sh; then
        echo "WARNING: MySQL data loading failed with exit code $?. Continuing with setup, but Metabase may not have sample data."
      else
        echo "MySQL data loading completed successfully."
      fi
    )
  else
    echo "Failed to download MySQL loader script. Skipping data load."
  fi
fi

# Deploy Metabase using Docker with tunneled database connections
echo "Starting Metabase container..."

# Check if a Metabase container already exists
if sudo docker ps -a | grep -q metabase; then
  echo "Metabase container already exists. Checking if it's running..."
  
  if sudo docker ps | grep -q metabase; then
    echo "Metabase container is already running. Using existing container."
  else
    echo "Metabase container exists but is not running. Starting it..."
    sudo docker start metabase
  fi
else
  echo "No existing Metabase container found. Creating a new one..."
  
  # Pull the latest Metabase image first
  echo "Pulling latest Metabase image..."
  sudo docker pull metabase/metabase
  
  # Run the Metabase container
  # Use H2 embedded database for Metabase's own data to avoid auth issues
  # We'll still connect to MySQL for the data analysis
  echo "Starting Metabase with H2 embedded database..."
  sudo docker run -d -p 3000:3000 --name metabase \
    -e "MB_DB_TYPE=h2" \
    -e "MB_DB_FILE=/metabase-data/metabase.db" \
    -e "MB_SETUP_ADMIN_EMAIL=admin@fincard.com" \
    -e "MB_SETUP_ADMIN_FIRST_NAME=Admin" \
    -e "MB_SETUP_ADMIN_LAST_NAME=User" \
    -e "MB_SETUP_ADMIN_PASSWORD=FinCard123!" \
    -v /home/ec2-user/metabase-data:/metabase-data \
    --restart always \
    --network=host \
    metabase/metabase
    
  echo "Metabase will use H2 embedded database for its own data."
  echo "It will be configured to connect to MySQL for analytics data separately."
fi

# Create directory for Metabase data if it doesn't exist
if [ ! -d /home/ec2-user/metabase-data ]; then
  sudo mkdir -p /home/ec2-user/metabase-data
  sudo chown ec2-user:ec2-user /home/ec2-user/metabase-data
fi

# Verify Metabase container is running
if ! sudo docker ps | grep -q metabase; then
  echo "ERROR: Failed to start Metabase container. Attempting to debug..."
  sudo docker logs metabase
  echo "Checking Docker service status..."
  sudo systemctl status docker --no-pager
fi

# Function to check if Metabase is ready
check_metabase_ready() {
  curl -s http://localhost:3000/ > /dev/null
  return $?
}

# Run the Metabase setup script with proper waiting
echo "Preparing to set up Metabase with MySQL connection..."
if [ -f /home/ec2-user/setup_metabase.sh ]; then
  chmod +x /home/ec2-user/setup_metabase.sh
  
  # Start a background process to wait for Metabase and run setup
  (
    echo "Waiting for Metabase to become available..."
    
    # Wait for Metabase to start, with timeout
    MAX_WAIT=300  # 5 minutes timeout
    START_TIME=$(date +%s)
    
    while ! check_metabase_ready; do
      CURRENT_TIME=$(date +%s)
      ELAPSED=$((CURRENT_TIME - START_TIME))
      
      if [ $ELAPSED -gt $MAX_WAIT ]; then
        echo "Timed out waiting for Metabase to start after $MAX_WAIT seconds"
        break
      fi
      
      echo "Waiting for Metabase to start... ($ELAPSED seconds elapsed)"
      sleep 10
    done
    
    if check_metabase_ready; then
      echo "Metabase is now available. Waiting 30 more seconds for it to fully initialize..."
      sleep 30
      
      # Pass environment variables to the setup script
      export mysql_host="${mysql_host}"
      export mysql_port="${mysql_port}"
      export mysql_username="${mysql_username}"
      export mysql_password="${mysql_password}"
      export s3_bucket="${s3_bucket_name}"
      export script_version="${script_version}"
      
      # Execute the setup script
      echo "Executing Metabase setup script..."
      /home/ec2-user/setup_metabase.sh
      SETUP_RESULT=$?
      
      if [ $SETUP_RESULT -eq 0 ]; then
        echo "Metabase setup completed successfully."
      else
        echo "WARNING: Metabase setup script exited with code $SETUP_RESULT"
      fi
    else
      echo "ERROR: Metabase did not become available within the timeout period."
      echo "Check Docker logs for more information: docker logs metabase"
    fi
  ) &
  
  # Save the PID of the background process to a file for reference
  echo $! > /tmp/metabase_setup.pid
  echo "Metabase setup process started in background (PID: $(cat /tmp/metabase_setup.pid))"
else
  echo "Metabase setup script not found at /home/ec2-user/setup_metabase.sh"
  echo "Attempting to download it directly..."
  
  if aws s3 cp s3://${s3_bucket_name}/setup_metabase.sh /home/ec2-user/setup_metabase.sh; then
    chmod +x /home/ec2-user/setup_metabase.sh
    echo "Downloaded setup script. Starting setup in background..."
    
    # Run setup in background
    (
      echo "Waiting for Metabase to become available..."
      # Similar waiting logic as above
      MAX_WAIT=300
      START_TIME=$(date +%s)
      
      while ! check_metabase_ready; do
        CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - START_TIME))
        
        if [ $ELAPSED -gt $MAX_WAIT ]; then
          echo "Timed out waiting for Metabase to start after $MAX_WAIT seconds"
          break
        fi
        
        echo "Waiting for Metabase to start... ($ELAPSED seconds elapsed)"
        sleep 10
      done
      
      if check_metabase_ready; then
        sleep 30
        export mysql_host="${mysql_host}"
        export mysql_port="${mysql_port}"
        export mysql_username="${mysql_username}"
        export mysql_password="${mysql_password}" 
        export s3_bucket="${s3_bucket_name}"
        export script_version="${script_version}"
        
        /home/ec2-user/setup_metabase.sh
      else
        echo "ERROR: Metabase did not become available within the timeout period."
      fi
    ) &
    
    echo $! > /tmp/metabase_setup.pid
  else
    echo "Failed to download Metabase setup script. Skipping automated setup."
    echo "You will need to manually configure Metabase after instance is ready."
  fi
fi

echo "Metabase instance setup completed!"