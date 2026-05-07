"""
Unit tests for the Flask API endpoints.

Run with:  pytest tests/test_app.py -v
"""

import json
import pytest
from app import app


@pytest.fixture
def client():
    """Provide a Flask test client configured for the app."""
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client


# =============================================================================
# GET /  — Root endpoint
# =============================================================================
def test_root_returns_200(client):
    response = client.get("/")
    assert response.status_code == 200


def test_root_returns_correct_message(client):
    response = client.get("/")
    data = json.loads(response.data)
    assert data["message"] == "Automated API Infrastructure"
    assert data["version"] == "1.0.0"


# =============================================================================
# GET /health  — Health-check endpoint
# =============================================================================
def test_health_returns_200(client):
    response = client.get("/health")
    assert response.status_code == 200


def test_health_contains_required_fields(client):
    response = client.get("/health")
    data = json.loads(response.data)
    assert data["status"] == "healthy"
    assert "timestamp" in data
    assert "uptime_seconds" in data


def test_health_uptime_is_positive(client):
    response = client.get("/health")
    data = json.loads(response.data)
    assert data["uptime_seconds"] >= 0


# =============================================================================
# GET /info  — Metadata endpoint
# =============================================================================
def test_info_returns_200(client):
    response = client.get("/info")
    assert response.status_code == 200


def test_info_contains_required_fields(client):
    response = client.get("/info")
    data = json.loads(response.data)
    assert "hostname" in data
    assert "environment" in data
    assert "docker" in data


def test_info_environment_is_production_by_default(client):
    response = client.get("/info")
    data = json.loads(response.data)
    assert data["environment"] == "production"
