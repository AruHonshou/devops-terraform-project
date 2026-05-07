"""
Flask API — Automated API Infrastructure

Three endpoints to demonstrate the infrastructure is operational:
  GET /         — Welcome message with project info
  GET /health   — Health check with uptime and timestamp
  GET /info     — Host and environment metadata
"""

import os
import time
import socket
from datetime import datetime, timezone

from flask import Flask, jsonify

# =============================================================================
# APP INITIALIZATION
# =============================================================================
# Capture the boot timestamp once so /health can calculate uptime.
# The HOSTNAME env var is always set in Docker containers.
# =============================================================================

app = Flask(__name__)
BOOT_TIME = time.time()
STARTED_AT = datetime.now(timezone.utc).isoformat()


# =============================================================================
# GET /
# =============================================================================
# The root endpoint — a recruiter lands here and immediately sees what this
# project is about. No database, no secrets, just a static response.
# =============================================================================
@app.route("/", methods=["GET"])
def root():
    return jsonify({
        "message": "Automated API Infrastructure",
        "version": "1.0.0",
        "ci_cd": "GitHub Actions",
    })


# =============================================================================
# GET /health
# =============================================================================
# Standard health-check endpoint. Returns HTTP 200 when the app is alive.
# Includes uptime so operators can detect unexpected restarts.
# =============================================================================
@app.route("/health", methods=["GET"])
def health():
    uptime = round(time.time() - BOOT_TIME, 2)
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "uptime_seconds": uptime,
    })


# =============================================================================
# GET /info
# =============================================================================
# Returns metadata about the running instance: hostname, environment tag,
# and whether we are inside Docker. Useful for debugging in production.
# =============================================================================
@app.route("/info", methods=["GET"])
def info():
    return jsonify({
        "hostname": socket.gethostname(),
        "environment": os.environ.get("APP_ENV", "production"),
        "docker": os.path.exists("/.dockerenv"),
    })


# =============================================================================
# ENTRYPOINT
# =============================================================================
# Gunicorn imports the app object directly, so this block only runs when
# executing `python app.py` (development). In production Gunicorn handles
# the WSGI server and the if-block is skipped.
# =============================================================================
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
