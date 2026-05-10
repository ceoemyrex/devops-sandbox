#!/bin/bash

# Cleanup daemon - runs every 60 seconds
LOG_FILE="logs/cleanup.log"
CLEANUP_INTERVAL=${CLEANUP_INTERVAL:-60}

mkdir -p logs envs

log_message() {
    local msg="$1"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "[$timestamp] $msg" >> $LOG_FILE
    echo "[$timestamp] $msg"
}

log_message "Cleanup daemon started (interval: ${CLEANUP_INTERVAL}s)"

while true; do
    for state_file in envs/*.json; do
        if [ ! -f "$state_file" ]; then
            continue
        fi
        
        ENV_ID=$(basename $state_file .json)
        
        created_at=$(grep '"created_at"' $state_file | cut -d'"' -f4)
        ttl_seconds=$(grep '"ttl_seconds"' $state_file | cut -d':' -f2 | cut -d',' -f1)
        
        created_timestamp=$(date -d "$created_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created_at" +%s 2>/dev/null || echo 0)
        current_timestamp=$(date +%s)
        age=$((current_timestamp - created_timestamp))
        
        if [ $age -gt $ttl_seconds ]; then
            log_message "TTL expired for $ENV_ID (age: ${age}s, ttl: ${ttl_seconds}s)"
            bash platform/destroy_env.sh $ENV_ID 2>/dev/null || true
            log_message "Destroyed $ENV_ID"
        fi
    done
    
    sleep $CLEANUP_INTERVAL
done

