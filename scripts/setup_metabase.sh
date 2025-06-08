#!/bin/bash
set -e

# Metabase API automation script
echo "Starting Metabase setup automation..."

# Variables will be replaced by Terraform
MYSQL_HOST="${mysql_host}"
MYSQL_PORT="${mysql_port}"
MYSQL_USERNAME="${mysql_username}"
MYSQL_PASSWORD="${mysql_password}"
S3_BUCKET="${s3_bucket}"
VERSION="${script_version}"

# Wait for Metabase to initialize (usually takes a minute or two)
echo "Waiting for Metabase to initialize..."
MAX_RETRIES=30
RETRY=0

while [ $RETRY -lt $MAX_RETRIES ]; do
  if curl -s http://localhost:3000/ > /dev/null; then
    echo "Metabase is running!"
    break
  fi
  echo "Waiting for Metabase to start... ($RETRY/$MAX_RETRIES)"
  sleep 10
  RETRY=$((RETRY+1))
done

if [ $RETRY -eq $MAX_RETRIES ]; then
  echo "Metabase failed to start after 5 minutes. Exiting setup."
  exit 1
fi

# Wait a bit more to ensure the API is ready
sleep 30

# Get the Metabase setup token
echo "Getting Metabase setup token..."
SETUP_TOKEN=$(curl -s http://localhost:3000/api/session/properties | grep -o '"setup-token":"[^"]*"' | cut -d '"' -f 4)

if [ -z "$SETUP_TOKEN" ]; then
  echo "Failed to get setup token. Metabase might already be configured."
  exit 0
fi

echo "Setup token obtained: $SETUP_TOKEN"

# Admin credentials
ADMIN_EMAIL="admin@fincard.example"
ADMIN_PASSWORD="FinCard123!"

# Function to login and get session token
login_to_metabase() {
  echo "Attempting to login to Metabase with $ADMIN_EMAIL..."
  local login_response=$(curl -s -X POST http://localhost:3000/api/session \
    -H "Content-Type: application/json" \
    -d "{\"username\": \"$ADMIN_EMAIL\", \"password\": \"$ADMIN_PASSWORD\"}")
  
  echo "Login response: $login_response"
  local session_token=$(echo "$login_response" | grep -o '"id":"[^"]*"' | cut -d '"' -f 4)
  
  echo $session_token
}

# Try to create the initial admin user (this may fail if already initialized)
if [ -n "$SETUP_TOKEN" ]; then
  echo "Creating Metabase admin user..."
  SETUP_RESPONSE=$(curl -s -X POST http://localhost:3000/api/setup \
    -H "Content-Type: application/json" \
    -d @- <<EOF
  {
    "token": "$SETUP_TOKEN",
    "prefs": {
      "site_name": "FinCard Analytics",
      "site_locale": "en",
      "allow_tracking": false
    },
    "user": {
      "first_name": "Admin",
      "last_name": "User",
      "email": "$ADMIN_EMAIL",
      "password": "$ADMIN_PASSWORD",
      "site_name": "FinCard Analytics"
    },
    "database": null
  }
EOF
  )

  echo "Setup response: $SETUP_RESPONSE"
fi

# Try with default credentials first
echo "Logging in to Metabase..."
SESSION_TOKEN=$(login_to_metabase)

# If login fails, try with a few common default credentials
if [ -z "$SESSION_TOKEN" ]; then
  echo "Default login failed. Trying alternative credentials..."
  
  # List of common email/password combinations to try
  CREDENTIALS=(
    "admin@example.com FinCard123!"
    "admin@metabase.local admin123"
    "admin@metabase.com metabase123"
  )
  
  for cred in "${CREDENTIALS[@]}"; do
    read -r email password <<< "$cred"
    ADMIN_EMAIL="$email"
    ADMIN_PASSWORD="$password"
    
    SESSION_TOKEN=$(login_to_metabase)
    if [ -n "$SESSION_TOKEN" ]; then
      echo "Successfully logged in with $ADMIN_EMAIL"
      break
    fi
  done
fi

# If still no token, try to reset admin password or give up
if [ -z "$SESSION_TOKEN" ]; then
  echo "WARNING: All login attempts failed."
  echo "Checking if password reset is available..."
  
  # Check if password reset endpoint is available
  RESET_CHECK=$(curl -s http://localhost:3000/api/session/reset_password)
  
  if echo "$RESET_CHECK" | grep -q "email"; then
    echo "Password reset is available, but we cannot automate this process."
    echo "Please manually login to Metabase at http://localhost:3000 and set up your database connection."
  else
    echo "Unable to access Metabase admin. Skipping database connection setup."
  fi
  
  echo "You will need to manually configure Metabase database connections."
  exit 0
fi

echo "Session token obtained: $SESSION_TOKEN"

# Function to test MySQL connection
test_mysql_connection() {
  local host=$1
  local port=$2
  
  echo "Testing MySQL connection to $host:$port..."
  mysql -h $host -P $port -u $MYSQL_USERNAME -p$MYSQL_PASSWORD -e "SELECT 1" > /dev/null 2>&1
  return $?
}

# Determine the best connection method for Metabase
echo "Testing MySQL connections for Metabase..."
if test_mysql_connection "localhost" "3307"; then
  echo "Tunnel connection to MySQL is working, using it for Metabase"
  CONN_HOST="localhost"
  CONN_PORT="3307"
else
  echo "Tunnel connection failed, trying direct connection..."
  if test_mysql_connection "$MYSQL_HOST" "$MYSQL_PORT"; then
    echo "Direct connection to MySQL is working, using it for Metabase"
    CONN_HOST="$MYSQL_HOST"
    CONN_PORT="$MYSQL_PORT"
  else
    echo "WARNING: Both tunnel and direct MySQL connections failed!"
    echo "Will attempt to configure Metabase with direct connection, but it may not work."
    CONN_HOST="$MYSQL_HOST"
    CONN_PORT="$MYSQL_PORT"
  fi
fi

# Verify database exists
echo "Verifying that fincard_mysql database exists..."
if mysql -h $CONN_HOST -P $CONN_PORT -u $MYSQL_USERNAME -p$MYSQL_PASSWORD -e "USE fincard_mysql;" > /dev/null 2>&1; then
  echo "Database fincard_mysql exists and is accessible"
else
  echo "WARNING: Could not access fincard_mysql database! Creating it now..."
  mysql -h $CONN_HOST -P $CONN_PORT -u $MYSQL_USERNAME -p$MYSQL_PASSWORD -e "CREATE DATABASE IF NOT EXISTS fincard_mysql;"
fi

# Add MySQL database connection
echo "Adding MySQL database connection to Metabase..."
DB_RESPONSE=$(curl -s -X POST http://localhost:3000/api/database \
  -H "Content-Type: application/json" \
  -H "X-Metabase-Session: $SESSION_TOKEN" \
  -d @- <<EOF
{
  "name": "FinCard MySQL",
  "engine": "mysql",
  "details": {
    "host": "$CONN_HOST",
    "port": $CONN_PORT,
    "dbname": "fincard_mysql",
    "user": "$MYSQL_USERNAME",
    "password": "$MYSQL_PASSWORD",
    "ssl": false,
    "additional-options": "useSSL=false&allowPublicKeyRetrieval=true&passwordCharacterEncoding=utf8",
    "tunnel-enabled": false
  },
  "is_full_sync": true,
  "is_on_demand": false,
  "auto_run_queries": true
}
EOF
)

# Check if the database connection was successful
if echo "$DB_RESPONSE" | grep -q '"id":[0-9]'; then
  echo "Successfully added MySQL database connection to Metabase"
  DB_ID=$(echo "$DB_RESPONSE" | grep -o '"id":[0-9]*' | cut -d ':' -f 2)
  echo "Database ID: $DB_ID"
  
  # Trigger a sync to load metadata
  echo "Triggering database sync..."
  curl -s -X POST "http://localhost:3000/api/database/$DB_ID/sync" \
    -H "X-Metabase-Session: $SESSION_TOKEN"
  
  echo "Database sync initiated"
else
  echo "WARNING: Failed to add MySQL database connection to Metabase"
  echo "Response: $DB_RESPONSE"
fi

echo "Metabase setup completed!"
echo "Login with admin@fincard.example / FinCard123!"
exit 0