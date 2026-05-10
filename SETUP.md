# How I Setup my Devops Sandbox

## Prerequisites

Make sure you have installed:

```bash
# Check what you have
which docker docker-compose python3 make git

# If it's missing, install with this cmd:
sudo apt install -y docker.io docker-compose make python3 python3-pip git

# Start Docker daemon
sudo systemctl start docker
sudo systemctl enable docker

# (Optional) Add your user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

## Setup Steps

### 1. Clone / Navigate to Project

```bash
cd /root/devops-sandbox  # or your project directory
```

### 2. Verify Structure

```bash
make help
```

Should show all available commands.

### 3. Build Images

```bash
make build
```

This builds three Docker images:
- `devops-sandbox-demo-app:latest` - Sample Flask app
- `devops-sandbox-nginx:latest` - Nginx reverse proxy
- `devops-sandbox-monitor:latest` - Health monitoring

### 4. Start Services

```bash
make up
```

This:
- Creates docker network `sandbox-platform`
- Starts Nginx container (listening on :8080)
- Starts health monitor container
- Starts API container (listening on :5000)
- Starts cleanup daemon in background

### 5. Verify Services Running

```bash
# Check containers
docker ps

# Check API
curl http://localhost:5000/health

# Should see: {"status": "healthy", "service": "devops-sandbox-api"}
```

## First Environment

### Create

```bash
make create

# Or via API
curl -X POST http://localhost:5000/envs \
  -H "Content-Type: application/json" \
  -d '{"name":"test-env","ttl":30}'
```

### Test

```bash
# Get environment ID from output
ENV_ID="env-1730752345-12345"

# Welcome endpoint
curl http://localhost:8080/$ENV_ID/

# Health check
curl http://localhost:8080/$ENV_ID/health

# List all
curl http://localhost:5000/envs

# Get logs
curl http://localhost:5000/envs/$ENV_ID/logs

# Simulate outage
curl -X POST http://localhost:5000/envs/$ENV_ID/outage \
  -H "Content-Type: application/json" \
  -d '{"mode":"crash"}'

# Recover
curl -X POST http://localhost:5000/envs/$ENV_ID/outage \
  -H "Content-Type: application/json" \
  -d '{"mode":"unpause"}'
```

## Troubleshooting

### Docker Not Running
```bash
sudo systemctl start docker
```

### Port Already in Use
Change in `.env`:
```
PLATFORM_API_PORT=5001
NGINX_PORT=8081
```

### Can't Connect to API
```bash
docker logs api-sandbox
```

### Containers Not Starting
```bash
# See all containers
docker ps -a

# Check logs
docker logs container-name

# Rebuild
make down
make clean
make build
make up
```

### File Permission Issues
```bash
chmod +x platform/*.sh
```

##Cleanup

### Stop Everything
```bash
make down
```

### Wipe All State
```bash
make clean
```

### Remove Images
```bash
docker rmi devops-sandbox-demo-app devops-sandbox-nginx devops-sandbox-monitor
```
