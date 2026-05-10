.PHONY: help up down create destroy logs health simulate clean build

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

up:
	@echo "Starting services..."

down:
	@echo "Stopping services..."

create:
	@echo "Creating environment..."

destroy:
	@echo "Destroying environment..."

logs:
	@echo "Showing logs..."

health:
	@echo "Showing health status..."

simulate:
	@echo "Simulating outage..."

clean:
	@echo "Cleaning all state..."
