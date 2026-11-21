.PHONY: help start shell logs stop clean test-environment

# Check if containers are running
RUNNING_CONTAINERS := $(shell docker compose ps --filter "status=running" --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')

help: ## Show this help message
	@echo 'DBT Case Study Environment'
	@echo '=========================='
	@echo ''
	@echo 'Quick Start:'
	@echo '  make start    - Start the environment'
	@echo '  make shell    - Enter interactive DBT shell'
	@echo '  make logs     - View container logs'
	@echo '  make stop     - Stop the environment'
	@echo ''
	@echo 'Available commands:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Dynamic start behavior based on container status
start: $(if $(filter 0,$(RUNNING_CONTAINERS)),start-containers,containers-running) ## Start the complete environment (PostgreSQL + DBT)

shell: start ## Enter interactive shell in the DBT container
	@echo "Entering DBT environment..."
	@echo "Once inside, you can run:"
	@echo "  dbt run      - Execute your models"
	@echo "  dbt test     - Run data tests"
	@echo "  dbt docs generate && dbt docs serve --host 0.0.0.0  - View documentation"
	@echo ""
	docker compose exec dbt /bin/bash

logs: ## Show logs from containers
	docker compose logs -f

stop: ## Stop all containers
	docker compose down

clean: ## Clean up everything (containers, volumes, generated files)
	docker compose down -v
	rm -rf target/ logs/ dbt_packages/

start-containers:
	@echo "Starting DBT case study environment..."
	docker compose up --build -d
	@echo "Waiting for setup to complete..."
	@sleep 10
	@echo ""
	@echo "Environment is ready! 🎉"
	@echo ""
	@echo "Next steps:"
	@echo "  make shell  - Enter the DBT environment"
	@echo "  make logs   - View setup logs"

containers-running:
	@echo "Containers are already running!"
	@echo "Use 'make stop' first if you want to restart, or 'make shell' to enter the environment."

test-environment: ## Test that the environment is working
	@echo "Testing DBT environment..."
	docker compose exec dbt dbt --version
	docker compose exec dbt dbt debug
	@echo "Environment test complete!"
	docker compose exec dbt dbt --version
	docker compose exec dbt dbt debug
	@echo "Environment test complete!"
