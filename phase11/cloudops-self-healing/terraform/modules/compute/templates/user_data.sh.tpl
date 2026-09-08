#!/bin/bash
set -euxo pipefail

# ---------------------------------------------------------------------------
# CloudOps bootstrap script
#
# Runs once, automatically, on first boot via EC2 user-data (cloud-init).
# Installs Docker, authenticates to ECR, and starts the app container
# with its logs shipped directly to CloudWatch Logs.
#
# Values in ${...} below are interpolated by Terraform's templatefile()
# function at plan/apply time — they are NOT shell variables set at
# runtime.
# ---------------------------------------------------------------------------

exec > >(tee /var/log/cloudops-bootstrap.log) 2>&1

echo "=== CloudOps bootstrap starting at $(date -u) ==="

# ---- Install Docker ----
dnf update -y
dnf install -y docker

systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user || true

# ---- Authenticate Docker to ECR using the instance's IAM role ----
aws ecr get-login-password --region "${aws_region}" \
  | docker login --username AWS --password-stdin "${ecr_registry}"

# ---- Pull the application image ----
IMAGE="${ecr_repository_url}:${image_tag}"
echo "Pulling $IMAGE"
docker pull "$IMAGE"

# ---- Get this instance's ID (IMDSv2 — token required, per Phase 7's
#      metadata_options hardening) so each instance's container logs
#      land in their own CloudWatch log stream, identifiable by
#      instance. ----
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

# ---- Run the application container, shipping logs to CloudWatch ----
# The awslogs log driver sends container stdout/stderr straight to
# CloudWatch Logs — no separate CloudWatch Agent process required,
# since gunicorn already logs to stdout (Phase 2 decision) and the
# instance's IAM role already has the necessary logs:* permissions
# (CloudWatchAgentServerPolicy, attached in Phase 7).
docker run -d \
  --name cloudops-app \
  --restart unless-stopped \
  -p ${app_port}:${app_port} \
  -e APP_VERSION="${image_tag}" \
  --log-driver awslogs \
  --log-opt awslogs-region="${aws_region}" \
  --log-opt awslogs-group="${log_group_name}" \
  --log-opt awslogs-stream="$INSTANCE_ID" \
  --log-opt awslogs-create-group=true \
  "$IMAGE"

echo "=== CloudOps bootstrap complete at $(date -u) ==="
