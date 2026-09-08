"""
Tests for the CloudOps application.

Run with: pytest app/tests/test_app.py -v
"""

import os
import sys

# Allow importing app.py from the parent directory when running
# pytest directly from the app/ folder or the repo root.
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import pytest
from app import app as flask_app


@pytest.fixture
def client():
    flask_app.config["TESTING"] = True
    with flask_app.test_client() as client:
        yield client


def test_index_returns_200(client):
    response = client.get("/")
    assert response.status_code == 200


def test_index_contains_expected_fields(client):
    response = client.get("/")
    data = response.get_json()
    assert "message" in data
    assert "status" in data
    assert "hostname" in data


def test_health_returns_200(client):
    response = client.get("/health")
    assert response.status_code == 200


def test_health_status_is_healthy(client):
    response = client.get("/health")
    data = response.get_json()
    assert data["status"] == "healthy"


def test_health_includes_timestamp(client):
    response = client.get("/health")
    data = response.get_json()
    assert "timestamp" in data


def test_version_returns_200(client):
    response = client.get("/version")
    assert response.status_code == 200


def test_version_default_value(client):
    """Without APP_VERSION set, should fall back to the dev default."""
    response = client.get("/version")
    data = response.get_json()
    assert "version" in data
    assert data["version"] == "0.0.0-dev"


def test_nonexistent_route_returns_404(client):
    response = client.get("/does-not-exist")
    assert response.status_code == 404
