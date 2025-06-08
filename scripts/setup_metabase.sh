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

# Get the Metabase setup token with multiple attempts
echo "Getting Metabase setup token..."
MAX_TOKEN_ATTEMPTS=5
TOKEN_ATTEMPT=1
SETUP_TOKEN=""

while [ $TOKEN_ATTEMPT -le $MAX_TOKEN_ATTEMPTS ] && [ -z "$SETUP_TOKEN" ]; do
  echo "Attempt $TOKEN_ATTEMPT to get setup token..."
  PROPERTIES=$(curl -s http://localhost:3000/api/session/properties)
  SETUP_TOKEN=$(echo "$PROPERTIES" | jq -r '.["setup-token"] // empty')
  
  if [ -n "$SETUP_TOKEN" ]; then
    echo "Setup token obtained: $SETUP_TOKEN"
    break
  else
    echo "No setup token found. This could mean Metabase is already configured or not ready yet."
    
    # Check if we have a 'setup-token' field at all
    if echo "$PROPERTIES" | grep -q "setup-token"; then
      echo "Setup token field found but empty. Metabase is still initializing."
    else
      echo "No setup token field found. Metabase is likely already configured."
    fi
    
    if [ $TOKEN_ATTEMPT -lt $MAX_TOKEN_ATTEMPTS ]; then
      echo "Waiting 10 seconds before retry..."
      sleep 10
    fi
    
    TOKEN_ATTEMPT=$((TOKEN_ATTEMPT+1))
  fi
done

# Even if we don't get a token, continue with login attempts
# as Metabase might already be configured

# Admin credentials - these match the env vars set in the container
ADMIN_EMAIL="admin@fincard.com"
ADMIN_PASSWORD="FinCard123!"

# We're going to use a completely different approach to get the session token

# Try to create the initial admin user (this may fail if already initialized)
if [ -n "$SETUP_TOKEN" ]; then
  echo "Creating Metabase admin user..."
  
  # Create a temporary file for the setup JSON
  TEMP_SETUP_FILE=$(mktemp)
  
  # Write the JSON to the file
  cat > "$TEMP_SETUP_FILE" << EOF
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
  
  # Use the file with curl
  SETUP_RESPONSE=$(curl -s -X POST http://localhost:3000/api/setup \
    -H "Content-Type: application/json" \
    -d @"$TEMP_SETUP_FILE")
  
  # Clean up temp file
  rm -f "$TEMP_SETUP_FILE"

  echo "Setup response: $SETUP_RESPONSE"
fi

# Use our new approach to get a clean session token
echo "Getting session token..."
# Read the token from the file to avoid any debug output
SESSION_TOKEN=""

# Check if we got a valid token

  # If token is empty, try once more after waiting
  if [ -z "$SESSION_TOKEN" ]; then
    echo "Initial login attempt failed. Waiting for Metabase to initialize..."
    sleep 30
    
    # Try again
  SESSION_TOKEN=$(curl -s -X POST http://localhost:3000/api/session \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}" | jq -r '.id')
    
    # Check again
    if [[ "$SESSION_TOKEN" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
      echo "Successfully obtained clean session token on second attempt: $SESSION_TOKEN"
    else
      echo "Warning: Token still not valid: '$SESSION_TOKEN'"
    fi
  fi

# If still no token, try a simpler direct approach with hardcoded session token
if [ -z "$SESSION_TOKEN" ]; then
  echo "WARNING: Login attempts failed. Trying direct database setup..."
  
  # Try with a direct approach (no session token)
  echo "Attempting direct database addition without authentication..."
  
  # Construct and print the curl command for reference
  DIRECT_CURL_COMMAND="curl -X POST http://localhost:3000/api/database \\
    -H \"Content-Type: application/json\" \\
    -d '{
      \"name\": \"FinCard MySQL\",
      \"engine\": \"mysql\",
      \"details\": {
        \"host\": \"$CONN_HOST\",
        \"port\": $CONN_PORT,
        \"dbname\": \"fincard_mysql\",
        \"user\": \"$MYSQL_USERNAME\",
        \"password\": \"$MYSQL_PASSWORD\"
      },
      \"is_full_sync\": true,
      \"is_on_demand\": false,
      \"cache_ttl\": null
    }'"
  
  # Print the command for reference
  echo "Executing the following command (without session token):"
  echo "$DIRECT_CURL_COMMAND"
  echo ""
  
  # Create a temporary file for the JSON payload
  DIRECT_JSON_FILE=$(mktemp)
  cat > "$DIRECT_JSON_FILE" << EOF
{
  "name": "FinCard MySQL",
  "engine": "mysql",
  "details": {
    "host": "$CONN_HOST",
    "port": $CONN_PORT,
    "dbname": "fincard_mysql",
    "user": "$MYSQL_USERNAME",
    "password": "$MYSQL_PASSWORD"
  },
  "is_full_sync": true,
  "is_on_demand": false,
  "cache_ttl": null
}
EOF
  
  # Try to add the database directly - no session token needed in some cases
  DB_DIRECT_RESPONSE=$(curl -s -X POST http://localhost:3000/api/database \
    -H "Content-Type: application/json" \
    -d @"$DIRECT_JSON_FILE")
    
  # Clean up the temporary file
  rm -f "$DIRECT_JSON_FILE"
  
  if echo "$DB_DIRECT_RESPONSE" | grep -q '"id":[0-9]'; then
    echo "Successfully added database without authentication!"
    exit 0
  else
    echo "Direct database addition failed."
    echo "You may need to manually configure the database connection."
    echo "Here are the credentials to use:"
    echo "Host: $CONN_HOST"
    echo "Port: $CONN_PORT"
    echo "Database: fincard_mysql"
    echo "Username: $MYSQL_USERNAME"
    echo "Password: $MYSQL_PASSWORD"
    exit 1
  fi
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

# Print the clean session token that will be used
echo "Using session token (should be a clean UUID): '$SESSION_TOKEN'"

# Create a clean curl command string for display
DISPLAY_CURL="curl -X POST http://localhost:3000/api/database \\
  -H \"Content-Type: application/json\" \\
  -H \"X-Metabase-Session: $SESSION_TOKEN\" \\
  -d '{
    \"name\": \"FinCard MySQL\",
    \"engine\": \"mysql\",
    \"details\": {
      \"host\": \"$CONN_HOST\",
      \"port\": $CONN_PORT,
      \"dbname\": \"fincard_mysql\",
      \"user\": \"$MYSQL_USERNAME\",
      \"password\": \"$MYSQL_PASSWORD\"
    },
    \"is_full_sync\": true,
    \"is_on_demand\": false,
    \"cache_ttl\": null
  }'"

# Print the command for reference
echo "Executing the following command:"
echo "$DISPLAY_CURL"
echo ""

# Create a temporary file for the JSON payload to avoid any issues with escaping
JSON_PAYLOAD_FILE=$(mktemp)
cat > "$JSON_PAYLOAD_FILE" << EOF
{
  "name": "FinCard MySQL",
  "engine": "mysql",
  "details": {
    "host": "$CONN_HOST",
    "port": $CONN_PORT,
    "dbname": "fincard_mysql",
    "user": "$MYSQL_USERNAME",
    "password": "$MYSQL_PASSWORD"
  },
  "is_full_sync": true,
  "is_on_demand": false,
  "cache_ttl": null
}
EOF

# Use curl with the clean session token and JSON from file
DB_RESPONSE=$(curl -s -X POST http://localhost:3000/api/database \
  -H "Content-Type: application/json" \
  -H "X-Metabase-Session: $SESSION_TOKEN" \
  -d @"$JSON_PAYLOAD_FILE")

# Clean up the temporary file
rm -f "$JSON_PAYLOAD_FILE"

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