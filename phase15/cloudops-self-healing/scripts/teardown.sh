#!/bin/bash
# ---------------------------------------------------------------------------
# teardown.sh — safely destroys ALL Terraform-managed infrastructure for
# this project, with explicit double-confirmation (this is destructive and
# cannot be undone for anything Terraform manages).
#
# Deliberately does NOT touch the S3 state bucket — see "What Persists"
# in docs/deployment.md for why, and how to remove it manually if you
# really want to.
#
# Usage: ./scripts/teardown.sh
# ---------------------------------------------------------------------------
set -euo pipefail

cd "$(dirname "$0")/../terraform/environments/dev"

echo "This will DESTROY all AWS resources managed by this Terraform"
echo "environment: VPC/networking, ALB, ASG + EC2 instances, ECR repository"
echo "(including all images in it), CloudWatch resources, and IAM roles."
echo "This cannot be undone."
echo
read -rp "Type the environment name (dev) to confirm you understand: " CONFIRM

if [ "$CONFIRM" != "dev" ]; then
  echo "Confirmation did not match. Aborting — nothing was destroyed."
  exit 1
fi

echo
echo "Generating destroy plan for review..."
terraform plan -destroy -out=destroy.tfplan

echo
echo "Review the plan above carefully."
read -rp "Type 'destroy' (exactly) to proceed: " FINAL_CONFIRM

if [ "$FINAL_CONFIRM" != "destroy" ]; then
  echo "Aborting — nothing was destroyed."
  rm -f destroy.tfplan
  exit 1
fi

terraform apply destroy.tfplan
rm -f destroy.tfplan

echo
echo "=== Destroy complete ==="
echo "Persisted (by design, not managed by Terraform):"
echo "  - S3 state bucket (see docs/deployment.md for manual removal steps)"
echo
echo "Note: GitHub repository Variables (AWS_ROLE_ARN, ECR_REPOSITORY_URL,"
echo "etc.) still reference the now-deleted resources. This is harmless"
echo "until you next push to main and CI/CD tries to use them — at that"
echo "point it will fail loudly (correctly), not silently."
