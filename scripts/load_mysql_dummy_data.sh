#!/bin/bash
set -e

# This script loads dummy data into MySQL
echo "Loading dummy data into MySQL..."

# Variables will be replaced by Terraform
MYSQL_HOST="${mysql_host}"
MYSQL_PORT="${mysql_port}"
MYSQL_USERNAME="${mysql_username}"
MYSQL_PASSWORD="${mysql_password}"
S3_BUCKET="${s3_bucket}"
VERSION="${script_version}"

# Make sure the tunnel is active
echo "Ensuring MySQL tunnel is active..."
/home/ec2-user/mysql_tunnel.sh start

# Maximum number of attempts to download the file
MAX_ATTEMPTS=5
ATTEMPT=1
SUCCESS=false

echo "Downloading MySQL dummy data from S3..."
while [ $ATTEMPT -le $MAX_ATTEMPTS ] && [ "$SUCCESS" = false ]; do
  echo "Attempt $ATTEMPT of $MAX_ATTEMPTS..."
  
  # Download the SQL script from S3 with versioning
  if aws s3 cp s3://$S3_BUCKET/mysql_dummy_data.sql /home/ec2-user/mysql_dummy_data.sql; then
    echo "Successfully downloaded MySQL dummy data from S3"
    SUCCESS=true
  else
    echo "Failed to download MySQL dummy data, retrying in 5 seconds..."
    sleep 5
    ATTEMPT=$((ATTEMPT+1))
  fi
done

if [ "$SUCCESS" = false ]; then
  echo "Failed to download MySQL dummy data after $MAX_ATTEMPTS attempts. Exiting."
  exit 1
fi

# Wait for tunnel to be fully established
echo "Waiting for MySQL tunnel to be fully established..."
sleep 5

# Function to test MySQL connection
test_mysql_connection() {
  local host=$1
  local port=$2
  
  echo "Testing MySQL connection to $host:$port..."
  mysql -h $host -P $port -u $MYSQL_USERNAME -p$MYSQL_PASSWORD -e "SELECT 1" > /dev/null 2>&1
  return $?
}

# Try tunnel connection first
if test_mysql_connection "localhost" "3307"; then
  echo "Tunnel connection successful, using tunnel for database operations"
  CONN_HOST="localhost"
  CONN_PORT="3307"
else
  echo "Tunnel connection failed, trying direct connection..."
  if test_mysql_connection $MYSQL_HOST $MYSQL_PORT; then
    echo "Direct connection successful, using direct connection for database operations"
    CONN_HOST=$MYSQL_HOST
    CONN_PORT=$MYSQL_PORT
  else
    echo "Both tunnel and direct connections failed. Check MySQL credentials and connectivity."
    exit 1
  fi
fi

# Create database if it doesn't exist
echo "Creating database if it doesn't exist..."
mysql -h $CONN_HOST -P $CONN_PORT -u $MYSQL_USERNAME -p$MYSQL_PASSWORD -e "CREATE DATABASE IF NOT EXISTS fincard_mysql;"
if [ $? -ne 0 ]; then
  echo "Failed to create database. Exiting."
  exit 1
fi

# Load the data
echo "Loading data into MySQL..."
mysql -h $CONN_HOST -P $CONN_PORT -u $MYSQL_USERNAME -p$MYSQL_PASSWORD fincard_mysql < /home/ec2-user/mysql_dummy_data.sql
if [ $? -ne 0 ]; then
  echo "Failed to load data. Exiting."
  exit 1
fi

echo "MySQL data loading complete!"
exit 0