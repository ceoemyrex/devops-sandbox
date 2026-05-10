#!/usr/bin/env python3
from flask import Flask, request, jsonify
import os
import json
import subprocess
import glob
import time
from pathlib import Path

app = Flask(__name__)

ENVS_DIR = Path("envs")
LOGS_DIR = Path("logs")
PLATFORM_API_PORT = int(os.getenv('PLATFORM_API_PORT', 5000))

def load_env_state(env_id):
    state_file = ENVS_DIR / f"{env_id}.json"
    if not state_file.exists():
        return None
    with open(state_file, 'r') as f:
        return json.load(f)

def get_all_envs():
    envs = []
    for state_file in glob.glob(str(ENVS_DIR / "*.json")):
        with open(state_file, 'r') as f:
            env = json.load(f)
            created = int(time.mktime(time.strptime(env['created_at'], '%Y-%m-%dT%H:%M:%SZ')))
            now = int(time.time())
            ttl_remaining = env['ttl_seconds'] - (now - created)
            env['ttl_remaining_seconds'] = max(0, ttl_remaining)
            envs.append(env)
    return envs

@app.route('/health')
def api_health():
    return jsonify({"status": "healthy", "service": "devops-sandbox-api"}), 200

@app.route('/envs', methods=['POST'])
def create_env():
    try:
        data = request.get_json() or {}
        name = data.get('name', f"sandbox-{int(time.time())}")
        ttl_minutes = data.get('ttl', 30)
        
        result = subprocess.run(
            ['bash', 'platform/create_env.sh', name, str(ttl_minutes)],
            capture_output=True,
            text=True,
            check=False
        )
        
        if result.returncode != 0:
            return jsonify({"error": result.stderr}), 500
        
        lines = result.stdout.strip().split('\n')
        env_id = lines[-1]
        env = load_env_state(env_id)
        
        return jsonify({"status": "created", "env": env}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/envs', methods=['GET'])
def list_envs():
    try:
        envs = get_all_envs()
        return jsonify({"count": len(envs), "envs": envs}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/envs/<env_id>', methods=['GET'])
def get_env(env_id):
    try:
        env = load_env_state(env_id)
        if not env:
            return jsonify({"error": "Environment not found"}), 404
        created = int(time.mktime(time.strptime(env['created_at'], '%Y-%m-%dT%H:%M:%SZ')))
        now = int(time.time())
        ttl_remaining = env['ttl_seconds'] - (now - created)
        env['ttl_remaining_seconds'] = max(0, ttl_remaining)
        return jsonify(env), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/envs/<env_id>', methods=['DELETE'])
def destroy_env(env_id):
    try:
        env = load_env_state(env_id)
        if not env:
            return jsonify({"error": "Environment not found"}), 404
        subprocess.run(['bash', 'platform/destroy_env.sh', env_id], capture_output=True, check=False)
        return jsonify({"status": "destroyed", "env_id": env_id}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/envs/<env_id>/logs', methods=['GET'])
def get_logs(env_id):
    try:
        log_file = LOGS_DIR / env_id / "app.log"
        if not log_file.exists():
            return jsonify({"error": "Logs not found"}), 404
        with open(log_file, 'r') as f:
            lines = f.readlines()
            last_100 = lines[-100:] if len(lines) > 100 else lines
        return jsonify({"env_id": env_id, "lines": len(last_100), "logs": ''.join(last_100)}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/envs/<env_id>/health', methods=['GET'])
def get_health(env_id):
    try:
        health_file = LOGS_DIR / env_id / "health.log"
        if not health_file.exists():
            return jsonify({"env_id": env_id, "checks": []}), 200
        with open(health_file, 'r') as f:
            lines = f.readlines()
            last_10 = lines[-10:] if len(lines) > 10 else lines
        checks = [json.loads(line) for line in last_10 if line.strip()]
        return jsonify({"env_id": env_id, "checks": checks}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/envs/<env_id>/outage', methods=['POST'])
def simulate_outage(env_id):
    try:
        data = request.get_json() or {}
        mode = data.get('mode', 'crash')
        if mode not in ['crash', 'pause', 'unpause', 'network', 'recover', 'stress']:
            return jsonify({"error": "Invalid mode"}), 400
        result = subprocess.run(
            ['bash', 'platform/simulate_outage.sh', '--env', env_id, '--mode', mode],
            capture_output=True, text=True, check=False
        )
        return jsonify({"status": "simulated", "env_id": env_id, "mode": mode, "output": result.stdout}), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Endpoint not found"}), 404

if __name__ == '__main__':
    ENVS_DIR.mkdir(exist_ok=True)
    LOGS_DIR.mkdir(exist_ok=True)
    print(f"Starting DevOps Sandbox API on port {PLATFORM_API_PORT}")
    app.run(host='0.0.0.0', port=PLATFORM_API_PORT, debug=False)
