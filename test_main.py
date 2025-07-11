"""Tests for the main application"""

import pytest
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)


def test_read_main():
    """Test the main index endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]


def test_health_check():
    """Test the health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    
    data = response.json()
    assert "status" in data
    assert data["status"] in ["healthy", "disabled"]
    
    if data["status"] == "healthy":
        assert "service" in data
        assert "version" in data
        assert "git_commit" in data


def test_security_headers():
    """Test that security headers are present"""
    response = client.get("/")
    
    # Check security headers
    assert "X-Content-Type-Options" in response.headers
    assert "X-Frame-Options" in response.headers
    assert "X-XSS-Protection" in response.headers
    assert "Referrer-Policy" in response.headers
    
    assert response.headers["X-Content-Type-Options"] == "nosniff"
    assert response.headers["X-Frame-Options"] == "DENY"


def test_process_time_header():
    """Test that process time header is added"""
    response = client.get("/health")
    assert "X-Process-Time" in response.headers
    
    # Process time should be a valid float
    process_time = float(response.headers["X-Process-Time"])
    assert process_time >= 0


def test_nonexistent_endpoint():
    """Test that nonexistent endpoints return 404"""
    response = client.get("/nonexistent")
    assert response.status_code == 404