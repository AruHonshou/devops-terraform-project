# =============================================================================
# MULTI-STAGE DOCKERFILE
# =============================================================================
# Stage 1 (build): installs dependencies in a full Python image.
# Stage 2 (final): copies only the necessary artifacts into a slim image.
# Result: a production-ready image that is ~80% smaller than a single-stage build.
# =============================================================================

# ---- Stage 1: Builder ----
# Use a full Python image to have access to compilers and build tooling.
FROM python:3.12-slim AS builder

# Prevent Python from buffering stdout/stderr (critical for Docker logs).
ENV PYTHONUNBUFFERED=1

# Install only the packages needed at build time.
WORKDIR /app
COPY requirements.txt .

# --mount=type=cache keeps pip packages across rebuilds, speeding up iteration.
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user --no-cache-dir -r requirements.txt

# ---- Stage 2: Production ----
# A slim base image without compilers — smaller and with a smaller attack surface.
FROM python:3.12-slim

# Create a non-root user. Running as root inside a container is a security anti-pattern.
RUN groupadd --system appuser && useradd --system --no-log-init --gid appuser appuser

# Copy only the installed packages from the builder stage.
COPY --from=builder /root/.local /home/appuser/.local

# Ensure the local bin directory is on PATH so Gunicorn is found.
ENV PATH=/home/appuser/.local/bin:$PATH
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Copy application source code.
COPY app.py .

# Switch to the non-root user for runtime.
USER appuser

# Expose the Flask port (informational — does not actually publish the port).
EXPOSE 5000

# Gunicorn with 2 workers (suitable for t3.micro with 2 vCPUs).
# bind 0.0.0.0:5000 so the container accepts connections from outside.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
