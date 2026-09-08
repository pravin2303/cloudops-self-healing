#!/bin/bash
# ---------------------------------------------------------------------------
# REFERENCE COPY — for reading and manual testing only.
#
# The actual bootstrap logic that runs on EC2 instances lives in:
#   terraform/modules/compute/templates/user_data.sh.tpl
#
# As of Phase 9, that template also ships container logs to CloudWatch
# via the awslogs Docker log driver — this reference copy is kept
# intentionally simple (no log shipping) for quick manual smoke tests.
#
# That version is a Terraform template (uses ${...} interpolation syntax
# that Terraform, not bash, resolves at apply time). This copy exists so
# the logic is easy to read/review without digging into terraform/, and
# so you can manually walk through the steps by hand if debugging a
# bootstrap failure over Session Manager.
#
# To manually reproduce what an instance does on boot, once connected
# via `aws ssm start-session`, fill in the values below and run this.
# ---------------------------------------------------------------------------

set -euxo pipefail

AWS_REGION="us-east-1"                                          # match your terraform.tfvars
ECR_REGISTRY="<account-id>.dkr.ecr.us-east-1.amazonaws.com"      # from: terraform output ecr_repository_url
ECR_REPOSITORY_URL="<account-id>.dkr.ecr.us-east-1.amazonaws.com/cloudops-dev-app"
IMAGE_TAG="v0.1.0"                                               # match your deployed tag
APP_PORT="5000"

dnf update -y
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user || true

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker pull "${ECR_REPOSITORY_URL}:${IMAGE_TAG}"

docker run -d \
  --name cloudops-app \
  --restart unless-stopped \
  -p "${APP_PORT}:${APP_PORT}" \
  -e APP_VERSION="$IMAGE_TAG" \
  "${ECR_REPOSITORY_URL}:${IMAGE_TAG}"

echo "Done. Verify with: curl http://localhost:${APP_PORT}/health"
