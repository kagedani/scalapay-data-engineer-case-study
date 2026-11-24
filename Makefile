.PHONY: help start shell logs stop clean test-environment build full-refresh docs insights all \
	start-containers containers-running ensure-running check-data

# Containers run as the host user, so files written to the mounted project are not owned by root.
export HOST_UID := $(shell id -u 2>/dev/null || echo 0)
export HOST_GID := $(shell id -g 2>/dev/null || echo 0)

# Non-interactive exec: works from scripts, CI and agents (no TTY needed).
DBT := docker compose exec -T dbt

# Optional arguments for build:
#   make build SELECT="path:models/star+"
#   make build VARS="{fct_orders_lookback_days: 3}"
SELECT ?=
VARS ?=

# Check if containers are running
RUNNING_CONTAINERS := $(shell docker compose ps --filter "status=running" --format "{{.Names}}" 2>/dev/null | wc -l | tr -d ' ')

help: ## Show this help message
	@echo 'DBT Case Study Environment'
	@echo '=========================='
	@echo ''
	@echo 'Quick Start:'
	@echo '  make start    - Start the environment (loads data/*.csv as seeds)'
	@echo '  make all      - Build and test every model, then render the insight charts'
	@echo '  make docs     - Serve the dbt docs on http://localhost:8080'
	@echo ''
	@echo 'Available commands:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-17s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Dynamic start behavior based on container status
start: $(if $(filter 0,$(RUNNING_CONTAINERS)),start-containers,containers-running) ## Start the complete environment (PostgreSQL + DBT)

shell: ensure-running ## Enter interactive shell in the DBT container
	docker compose exec dbt /bin/bash

logs: ## Show logs from containers
	docker compose logs -f

stop: ## Stop all containers
	docker compose down

clean: ## Clean up everything (containers, volumes, generated files)
	docker compose down -v
	rm -rf target/ logs/ dbt_packages/

test-environment: ensure-running ## Test that the environment is working
	@echo "Testing DBT environment..."
	$(DBT) dbt --version
	$(DBT) dbt debug
	@echo "Environment test complete!"

build: ensure-running ## Build and test models (optional SELECT="<selector>", VARS="<yaml>")
	$(DBT) dbt build $(if $(SELECT),--select "$(SELECT)") $(if $(VARS),--vars '$(VARS)')

full-refresh: ensure-running ## Rebuild everything from scratch, incremental fct_orders included
	$(DBT) dbt build --full-refresh

docs: ensure-running ## Generate and serve the dbt docs on http://localhost:8080 (Ctrl+C to stop)
	$(DBT) dbt docs generate
	@# TTY exec on purpose: without one, Ctrl+C would not stop the server inside the container.
	docker compose exec dbt dbt docs serve --host 0.0.0.0 --port 8080

insights: ensure-running ## Render docs/img/*.png from the queries in analyses/ (needs a build first)
	$(DBT) dbt compile --select path:analyses
	$(DBT) python scripts/insights_charts.py

all: build insights ## Build and test every model, then render the insight charts

ensure-running:
	@if [ "$$(docker compose ps --filter status=running --format '{{.Names}}' | wc -l | tr -d ' ')" = "0" ]; then \
		$(MAKE) --no-print-directory start-containers; \
	fi

DATA_FILES := customers orders products shipping_company

check-data:
	@missing=""; \
	for f in $(DATA_FILES); do [ -f "data/$$f.csv" ] || missing="$$missing data/$$f.csv"; done; \
	if [ -n "$$missing" ]; then \
		echo "Missing source files:$$missing"; \
		echo "Copy the four case-study CSV files into data/ (see README, Run it), then run make start again."; \
		exit 1; \
	fi

start-containers: check-data
	@echo "Starting DBT case study environment..."
	@since=$$(date -u +%Y-%m-%dT%H:%M:%SZ); \
	docker compose up --build -d && \
	echo "Waiting for setup to complete (dbt deps + dbt seed)..." && \
	for i in $$(seq 1 90); do \
		if docker compose logs --since "$$since" dbt 2>/dev/null | grep -q "DBT environment is ready!"; then \
			echo "Environment is ready! Next: make all"; exit 0; \
		fi; \
		sleep 2; \
	done; \
	echo "Setup did not finish within 3 minutes. Check: make logs"; exit 1

containers-running:
	@echo "Containers are already running!"
	@echo "Use 'make stop' first if you want to restart, or 'make shell' to enter the environment."
