#!/bin/bash
set -e

# Colors
GREEN='\033[92m'
RED='\033[91m'
RESET='\033[0m'

# Get arguments
ENV_NAME=${1:-"sandbox-$(date +%s)"}
TTL_MINUTES=${2:-30}
TTL_SECONDS=$((TTL_MINUTES * 60))

# Generate unique ID
ENV_ID="env-$(date +%s)-$RANDOM"
CREATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EXPIRES_AT=$(date -u -d "+${TTL_MINUTES} minutes" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v+${TTL_MINUTES}m +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")

# Ensure directories exist
mkdir -p envs logs/$ENV_ID nginx/conf.d

echo "Creating environment: $ENV_NAME"
echo "  ID: $ENV_ID"
echo "  TTL: ${TTL_MINUTES} minutes"

# Step 1: Create Docker network
NETWORK_NAME="sandbox-$ENV_ID"
docker network create $NETWORK_NAME 2>/dev/null || true
echo "✅ Network created: $NETWORK_NAME"

# Step 2: Start app container
CONTAINER_ID=$(docker run -d \
  --name "app-$ENV_ID" \
  --network $NETWORK_NAME \
  -e SANDBOX_ENV_ID=$ENV_ID \
  -e APP_PORT=3000 \
  -l "sandbox.env=$ENV_ID" \
  -l "sandbox.type=app" \
  --health-cmd="curl -f http://localhost:3000/health || exit 1" \
  --health-interval=10s \
  --health-timeout=5s \
  --health-retries=3 \
  devops-sandbox-demo-app:latest 2>/dev/null)

if [ -z "$CONTAINER_ID" ]; then
    echo "❌ Failed to start container"
    exit 1
fi

echo "✅ Container started: $CONTAINER_ID"

# Step 3: Create state file
STATE_FILE="envs/${ENV_ID}.json"
cat > "${STATE_FILE}.tmp" << JSON
{
  "id": "$ENV_ID",
  "name": "$ENV_NAME",
  "created_at": "$CREATED_AT",
  "expires_at": "$EXPIRES_AT",
  "ttl_seconds": $TTL_SECONDS,
  "status": "healthy",
  "container_id": "$CONTAINER_ID",
  "network": "$NETWORK_NAME",
  "port": 3000,
  "hostname": "app-$ENV_ID",
  "nginx_route": "http://localhost:8080/$ENV_ID"
}
JSON
mv "${STATE_FILE}.tmp" "$STATE_FILE"
echo "✅ State file created: $STATE_FILE"

# Step 4: Start log shipping
mkdir -p logs/$ENV_ID
docker logs -f $CONTAINER_ID >> logs/$ENV_ID/app.log 2>&1 &
LOG_PID=$!
echo $LOG_PID > logs/$ENV_ID/.log_pid
echo "✅ Log shipping started (PID: $LOG_PID)"

# Step 5: Create Nginx config
NGINX_CONF="nginx/conf.d/${ENV_ID}.conf"
cat > "${NGINX_CONF}.tmp" << NGINX
upstream app_$ENV_ID {
    server app-$ENV_ID:3000;
}

server {
    listen 8080;
    server_name localhost;
    
    location /$ENV_ID/ {
        proxy_pass http://app_$ENV_ID/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINX
mv "${NGINX_CONF}.tmp" "$NGINX_CONF"
echo "✅ Nginx config created: $NGINX_CONF"

# Step 6: Reload Nginx
docker exec nginx-sandbox nginx -s reload 2>/dev/null || echo "⚠️  Nginx may not be running yet"
echo "✅ Nginx reloaded"

# Print summary
echo ""
echo "========================================="
echo -e "${GREEN}✅ Environment Created!${RESET}"
echo "========================================="
echo "Environment ID: $ENV_ID"
echo "Name: $ENV_NAME"
echo "URL: http://localhost:8080/$ENV_ID"
echo "Expires in: ${TTL_MINUTES} minutes"
echo "Container: app-$ENV_ID"
echo "Network: $NETWORK_NAME"
echo "========================================="
echo ""

# Exit with success
echo $ENV_ID
