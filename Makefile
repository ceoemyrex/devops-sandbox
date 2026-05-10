.PHONY: help up down create destroy logs health simulate clean build

include .env
export

help:
	@echo "DevOps Sandbox Platform - Available Commands"
	@echo ""
	@echo "make up                            # Start all services"
	@echo "make down                          # Stop everything"
	@echo "make build                         # Build Docker images"
	@echo "make create                        # Create new environment"
	@echo "make destroy ENV=<id>              # Destroy environment"
	@echo "make logs ENV=<id>                 # Tail environment logs"
	@echo "make health                        # Show health status"
	@echo "make simulate ENV=<id> MODE=<m>   # Simulate outage"
	@echo "make clean                         # Wipe all state"
	@echo ""

build:
	@echo "Building Docker images..."
	docker build -t devops-sandbox-demo-app:latest demo-app/
	docker build -t devops-sandbox-nginx:latest nginx/
	docker build -t devops-sandbox-monitor:latest monitor/
	@echo "✅ Images built"

up: build
	@echo "Starting services..."
	docker network create sandbox-platform 2>/dev/null || true
	
	docker run -d --name nginx-sandbox \
	  --network sandbox-platform \
	  -p 8080:8080 \
	  -v $(PWD)/nginx/conf.d:/etc/nginx/conf.d \
	  devops-sandbox-nginx:latest || true
	
	docker run -d --name monitor-sandbox \
	  --network sandbox-platform \
	  -v $(PWD)/logs:/app/logs \
	  -v $(PWD)/envs:/app/envs \
	  devops-sandbox-monitor:latest || true
	
	docker run -d --name api-sandbox \
	  --network sandbox-platform \
	  -p 5000:5000 \
	  -v $(PWD):/app \
	  -v /var/run/docker.sock:/var/run/docker.sock \
	  -e PLATFORM_API_PORT=5000 \
	  -w /app \
	  python:3.11-slim bash -c "pip install flask requests && python platform/api.py" || true
	
	nohup bash platform/cleanup_daemon.sh > logs/cleanup.log 2>&1 &
	
	@echo "✅ Services started!"
	@echo "   API: http://localhost:5000"
	@echo "   Nginx: http://localhost:8080"

down:
	@echo "Stopping services..."
	docker stop api-sandbox 2>/dev/null || true
	docker stop nginx-sandbox 2>/dev/null || true
	docker stop monitor-sandbox 2>/dev/null || true
	docker rm api-sandbox 2>/dev/null || true
	docker rm nginx-sandbox 2>/dev/null || true
	docker rm monitor-sandbox 2>/dev/null || true
	docker network rm sandbox-platform 2>/dev/null || true
	@for env_file in envs/*.json; do \
		if [ -f "$$env_file" ]; then \
			env_id=$$(basename $$env_file .json); \
			bash platform/destroy_env.sh $$env_id; \
		fi \
	done
	@echo "✅ All services stopped"

create:
	@read -p "Enter environment name: " name; \
	read -p "Enter TTL in minutes (default 30): " ttl; \
	ttl=$${ttl:-30}; \
	bash platform/create_env.sh "$$name" $$ttl

destroy:
	@if [ -z "$(ENV)" ]; then echo "Usage: make destroy ENV=<env_id>"; exit 1; fi
	bash platform/destroy_env.sh $(ENV)

logs:
	@if [ -z "$(ENV)" ]; then echo "Usage: make logs ENV=<env_id>"; exit 1; fi
	tail -f logs/$(ENV)/app.log

health:
	@curl -s http://localhost:5000/envs | python3 -m json.tool 2>/dev/null || echo "API not running"

simulate:
	@if [ -z "$(ENV)" ] || [ -z "$(MODE)" ]; then \
		echo "Usage: make simulate ENV=<env_id> MODE=<crash|pause|unpause|network>"; \
		exit 1; \
	fi
	bash platform/simulate_outage.sh --env $(ENV) --mode $(MODE)

clean:
	@echo "Cleaning all state..."
	rm -rf logs/* envs/* nginx/conf.d/*.conf
	@echo "✅ Cleaned"
