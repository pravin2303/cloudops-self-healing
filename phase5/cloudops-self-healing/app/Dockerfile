# syntax=docker/dockerfile:1

# ---- Base image ----
# slim variant: full Debian userland stripped of docs/build tools.
# Meaningfully smaller than the default python:3.12 image while still
# using glibc (avoids musl-related wheel-compatibility issues alpine
# sometimes causes).
FROM python:3.12-slim

# ---- Build-time version injection ----
# Passed in by CI as: docker build --build-arg APP_VERSION=<git-sha> .
# Defaults to "0.0.0-dev" for local builds where nothing is passed.
ARG APP_VERSION=0.0.0-dev

# ---- Runtime configuration ----
# Baked in as ENV (not just ARG) so it's visible to the running process
# without needing to pass -e at `docker run` time — this is how the
# EC2 Launch Template will run the container in later phases.
ENV APP_VERSION=${APP_VERSION} \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# ---- Dependency layer (cached separately from app code) ----
# Copying requirements.txt first means Docker only re-runs `pip install`
# when dependencies actually change, not on every code edit — this
# meaningfully speeds up rebuilds locally and in CI.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# ---- Application code ----
COPY app.py .

# ---- Non-root user ----
# Running as root inside a container is unnecessary privilege that
# provides no benefit here. If the app is ever compromised, a non-root
# user limits what an attacker can do inside the container.
RUN useradd --create-home --shell /usr/sbin/nologin appuser \
    && chown -R appuser:appuser /app
USER appuser

# ---- Networking ----
EXPOSE 5000

# ---- Container-level health check ----
# Independent of the ALB's health check (which is authoritative once
# deployed to AWS). This one is useful for local `docker ps` visibility
# and any orchestrator that reads Docker's native HEALTHCHECK status.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health').read()" || exit 1

# ---- Entrypoint ----
# gunicorn, not the Flask dev server — matches Phase 1's design intent.
# 2 workers is a reasonable default for a t3.micro-class instance;
# revisit if CPU profiling later suggests otherwise.
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
