"""
CloudOps Self-Healing Infrastructure — Application

A minimal Flask REST API used to demonstrate AWS self-healing
infrastructure. Endpoints are intentionally simple: the focus of
this project is the surrounding cloud infrastructure, not the app.
"""

import os
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify

app = Flask(__name__)

# Version is injected at container build/run time via environment variable.
# This is what lets CI/CD prove a new version was actually deployed —
# never hardcode this string.
APP_VERSION = os.environ.get("APP_VERSION", "0.0.0-dev")

# Hostname lets us see which EC2 instance / container actually served
# a given request — useful when demonstrating load balancing across
# multiple instances in Phase 8.
HOSTNAME = socket.gethostname()


@app.route("/", methods=["GET"])
def index():
    """Basic landing endpoint — proves the app is reachable at all."""
    return jsonify(
        {
            "message": "CloudOps Self-Healing Infrastructure",
            "status": "running",
            "hostname": HOSTNAME,
        }
    ), 200


@app.route("/health", methods=["GET"])
def health():
    """
    Health check endpoint used by the ALB target group.

    Returns 200 with status "healthy" under normal operation.
    This is intentionally simple for now — a real production app
    might check database connectivity, disk space, dependent
    service availability, etc. For this project, we keep it
    lightweight since the app has no external dependencies yet,
    but the endpoint is structured so we can extend it later
    (e.g. during Phase 10 failure simulation) without changing
    its contract.
    """
    return jsonify(
        {
            "status": "healthy",
            "hostname": HOSTNAME,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
    ), 200


@app.route("/version", methods=["GET"])
def version():
    """
    Exposes the deployed application version.

    Used to verify, after a CI/CD deployment, that the new version
    is actually running — not just that the pipeline reported success.
    """
    return jsonify(
        {
            "version": APP_VERSION,
            "hostname": HOSTNAME,
        }
    ), 200


if __name__ == "__main__":
    # This block only runs during local development (python app.py).
    # In the container, gunicorn runs the app instead — see Dockerfile
    # in Phase 2. debug=False even here, to avoid the habit of
    # accidentally shipping debug=True.
    app.run(host="0.0.0.0", port=5000, debug=False)
