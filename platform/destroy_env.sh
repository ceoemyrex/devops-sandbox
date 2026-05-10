#!/bin/bash
set -e

ENV_ID=$1

if [ -z "$ENV_ID" ]; then
    echo "❌ Usage: destroy_env.sh <ENV_ID>"
    exit 1
fi

echo "Destroying environment: $ENV_ID"

# Check if env exists
if [ ! -f "envs/${ENV_ID}.json" ]; then
    echo "⚠️  Environment $ENV_ID not found"
    exit 0
fi

# Step 1: Kill log shipping process
if [ -f "logs/$ENV_ID/.log_pid" ]; then
    LOG_PID=$(cat logs/$ENV_ID/.log_pid 2>/dev/null)
    kill $LOG_PID 2>/dev/null || true
    rm -f logs/$ENV_ID/.log_pid
    echo "✅ Log shipping stopped"
fi

# Step 2: Stop and remove containers
docker ps -a 2>/dev/null | grep "app-$ENV_ID" | awk '{print $1}' | xargs -r docker stop 2>/dev/null || true
docker ps -a 2>/dev/null | grep "app-$ENV_ID" | awk '{print $1}' | xargs -r docker rm 2>/dev/null || true
echo "✅ Containers removed"

# Step 3: Remove Docker network
NETWORK_NAME="sandbox-$ENV_ID"
docker network rm $NETWORK_NAME 2>/dev/null || true
echo "✅ Network removed"

# Step 4: Remove Nginx config and reload
rm -f nginx/conf.d/${ENV_ID}.conf
docker exec nginx-sandbox nginx -s reload 2>/dev/null || true
echo "✅ Nginx config removed and reloaded"

# Step 5: Archive logs
mkdir -p logs/archived
tar czf logs/archived/${ENV_ID}.tar.gz logs/$ENV_ID/ 2>/dev/null || true
echo "✅ Logs archived"

# Step 6: Remove state file
rm -f envs/${ENV_ID}.json
echo "✅ State file deleted"

echo ""
echo "========================================="
echo "✅ Environment Destroyed: $ENV_ID"
echo "========================================="
echo ""

