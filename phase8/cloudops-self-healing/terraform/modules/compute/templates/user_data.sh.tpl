#!/bin/bash
set -euxo pipefail

# ---------------------------------------------------------------------------
# CloudOps bootstrap script
#
# Runs once, automatically, on first boot via EC2 user-data (cloud-init).
# This is what turns a blank Amazon Linux 2023 instance into a running
# application node — no manual SSH, no manual steps.
#
# Values below are interpolated by Terraform's templatefile() function
# at plan/apply time — they are NOT shell variables set at runtime.
# ---------------------------------------------------------------------------

# Send all output to a log file AND the console, so failures are visible
# both via `cat /var/log/cloudops-bootstrap.log` (over SSM) and in the
# EC2 console's system log if something goes wrong before SSM even starts.
exec > >(tee /var/log/cloudops-bootstrap.log) 2>&1

echo "=== CloudOps bootstrap starting at $(date -u) ==="

# ---- Install Docker ----
dnf update -y
dnf install -y docker

systemctl enable docker
systemctl start docker

# Convenience for manual debugging via Session Manager — lets ec2-user
# run docker commands without sudo. Not security-relevant since SSM
# session access is already gated by IAM.
usermod -aG docker ec2-user || true

# ---- Authenticate Docker to ECR using the instance's IAM role ----
# No access keys anywhere — this call uses the temporary credentials
# automatically supplied by the instance profile attached in main.tf.
aws ecr get-login-password --region "${aws_region}" \
  | docker login --username AWS --password-stdin "${ecr_registry}"

# ---- Pull the application image ----
# Always a specific, immutable tag — never "latest". This is what lets
# CI/CD (Phase 12) know exactly what's running and roll back precisely
# if needed.
IMAGE="${ecr_repository_url}:${image_tag}"
echo "Pulling $IMAGE"
docker pull "$IMAGE"

# ---- Run the application container ----
# --restart unless-stopped: if the container process itself crashes,
# Docker restarts it locally as a first line of defense. This does NOT
# replace the ALB + ASG self-healing loop — if the instance itself is
# unhealthy (not just the container), the ALB/ASG mechanism from
# Phase 8 is what actually replaces the instance.
docker run -d \
  --name cloudops-app \
  --restart unless-stopped \
  -p ${app_port}:${app_port} \
  -e APP_VERSION="${image_tag}" \
  "$IMAGE"

echo "=== CloudOps bootstrap complete at $(date -u) ==="
