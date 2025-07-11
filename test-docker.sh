#!/bin/bash

# Test Docker build and run script
set -e

echo "Building Docker image..."
docker build -t wudi-test:latest .

echo "Testing Docker image..."
docker run --rm -d --name wudi-test -p 8001:8000 wudi-test:latest

# Wait for container to start
sleep 5

echo "Testing health endpoint..."
curl -f http://localhost:8001/health || {
    echo "Health check failed"
    docker logs wudi-test
    docker stop wudi-test
    exit 1
}

echo "Testing main endpoint..."
curl -f http://localhost:8001/ || {
    echo "Main endpoint failed"
    docker logs wudi-test
    docker stop wudi-test
    exit 1
}

echo "Stopping test container..."
docker stop wudi-test

echo "Docker test completed successfully!"