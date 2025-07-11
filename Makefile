.PHONY: help install install-dev test lint format clean run docker-build docker-run

# Default target
help:
	@echo "Available commands:"
	@echo "  install      - Install production dependencies"
	@echo "  install-dev  - Install development dependencies"
	@echo "  test         - Run tests"
	@echo "  lint         - Run linting checks"
	@echo "  format       - Format code with black and isort"
	@echo "  clean        - Clean up cache files"
	@echo "  run          - Run the application locally"
	@echo "  docker-build - Build Docker image"
	@echo "  docker-run   - Run Docker container"

# Install production dependencies
install:
	uv sync --frozen --no-dev

# Install development dependencies
install-dev:
	uv sync --frozen

# Run tests
test:
	uv run pytest -v

# Run linting checks
lint:
	uv run flake8 .
	uv run mypy .

# Format code
format:
	uv run black .
	uv run isort .

# Clean up cache files
clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type d -name ".pytest_cache" -exec rm -rf {} +
	find . -type d -name ".mypy_cache" -exec rm -rf {} +

# Run the application locally
run:
	uv run python main.py

# Build Docker image
docker-build:
	docker build -t wudi-app:latest .

# Run Docker container
docker-run:
	docker run -p 8000:8000 --name wudi-container wudi-app:latest

# Stop and remove Docker container
docker-stop: ## Stop Docker container
	docker stop wudi-app || true
	docker rm wudi-app || true

docker-test: ## Test Docker build and run
	./test-docker.sh

docker-clean: ## Clean Docker images and containers
	docker stop wudi-app || true
	docker rm wudi-app || true
	docker rmi wudi:latest || true
	docker rmi wudi-test:latest || true

# Development server with auto-reload
dev: install-dev ## Start development server with auto-reload
	uv run uvicorn main:app --reload --host 0.0.0.0 --port 8000
