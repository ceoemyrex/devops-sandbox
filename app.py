#!/usr/bin/env python3
"""Simple demo app for sandbox testing"""

from flask import Flask, jsonify, request
import os
import time
import sys

app = Flask(__name__)

# Get environment variables
ENV_ID = os.getenv('SANDBOX_ENV_ID', 'unknown')
APP_PORT = int(os.getenv('APP_PORT', 3000))
START_TIME = time.time()

# Outage simulation state
outage_state = {
    'mode': None,
    'active': False
}

@app.route('/')
def welcome():
    return jsonify({
        "message": "Welcome to DevOps Sandbox",
        "env_id": ENV_ID,
        "timestamp": time.time(),
        "uptime_seconds": int(time.time() - START_TIME)
    }), 200

@app.route('/health')
def health():
    return jsonify({
        "status": "healthy",
        "env_id": ENV_ID,
        "timestamp": time.time(),
        "uptime_seconds": int(time.time() - START_TIME),
        "outage_mode": outage_state['mode']
    }), 200

@app.route('/outage', methods=['GET'])
def get_outage_status():
    return jsonify({
        "active": outage_state['active'],
        "mode": outage_state['mode'],
        "timestamp": time.time()
    }), 200

@app.route('/stress')
def stress_endpoint():
    """For testing - this endpoint does CPU work"""
    total = 0
    for i in range(100000000):
        total += i
    return jsonify({"result": total}), 200

@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Not found"}), 404

if __name__ == '__main__':
    print(f"Starting app for environment: {ENV_ID}")
    app.run(host='0.0.0.0', port=APP_PORT, debug=False)
