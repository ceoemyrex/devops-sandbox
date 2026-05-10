#!/usr/bin/env python3
import requests
import json
import glob
import time
import os
from pathlib import Path
from datetime import datetime

HEALTH_CHECK_INTERVAL = int(os.getenv('HEALTH_CHECK_INTERVAL', 30))
HEALTH_FAILURE_THRESHOLD = int(os.getenv('HEALTH_FAILURE_THRESHOLD', 3))
LOGS_DIR = Path('logs')

def check_env_health(env):
    env_id = env['id']
    url = f"http://app-{env_id}:3000/health"
    
    try:
        start = time.time()
        response = requests.get(url, timeout=5)
        latency = time.time() - start
        check = {
            "timestamp": datetime.utcnow().isoformat() + 'Z',
            "env_id": env_id,
            "status": response.status_code,
            "latency_ms": round(latency * 1000, 2),
            "healthy": response.status_code == 200
        }
    except Exception as e:
        check = {
            "timestamp": datetime.utcnow().isoformat() + 'Z',
            "env_id": env_id,
            "status": 0,
            "error": str(e),
            "healthy": False
        }
    
    log_file = LOGS_DIR / env_id / "health.log"
    log_file.parent.mkdir(parents=True, exist_ok=True)
    with open(log_file, 'a') as f:
        f.write(json.dumps(check) + '\n')
    
    return check

def update_env_status(env_id, status):
    state_file = Path('envs') / f"{env_id}.json"
    if not state_file.exists():
        return
    with open(state_file, 'r') as f:
        env = json.load(f)
    env['status'] = status
    with open(state_file, 'w') as f:
        json.dump(env, f, indent=2)

def main():
    print("Health poller started")
    failure_counts = {}
    
    while True:
        env_files = glob.glob('envs/*.json')
        for env_file in env_files:
            with open(env_file, 'r') as f:
                env = json.load(f)
            env_id = env['id']
            check = check_env_health(env)
            
            if not check['healthy']:
                failure_counts[env_id] = failure_counts.get(env_id, 0) + 1
                if failure_counts[env_id] >= HEALTH_FAILURE_THRESHOLD:
                    update_env_status(env_id, 'degraded')
                    print(f"⚠️  {env_id}: DEGRADED")
            else:
                if failure_counts.get(env_id, 0) > 0:
                    update_env_status(env_id, 'healthy')
                    print(f"✅ {env_id}: RECOVERED")
                failure_counts[env_id] = 0
        
        time.sleep(HEALTH_CHECK_INTERVAL)

if __name__ == '__main__':
    main()
