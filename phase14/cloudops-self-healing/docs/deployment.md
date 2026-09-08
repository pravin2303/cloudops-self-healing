# Deployment Guide

## Terraform Deployment

### One-time bootstrap: S3 state bucket

Terraform cannot create the S3 bucket it uses for its own backend, so this
happens once, manually, before the first `terraform init`:

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export TF_STATE_BUCKET="cloudops-tfstate-${AWS_ACCOUNT_ID}"

aws s3api create-bucket --bucket "$TF_STATE_BUCKET" --region us-east-1
aws s3api put-bucket-versioning --bucket "$TF_STATE_BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$TF_STATE_BUCKET" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$TF_STATE_BUCKET" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Update `terraform/environments/dev/providers.tf`'s `backend "s3"` block with
this bucket name, then:

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars   # fill in github_org, etc.
terraform init
terraform fmt -recursive ../../
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

State locking uses Terraform's native S3 locking (`use_lockfile = true`,
Terraform >= 1.10) — no separate DynamoDB table required.

## Docker Setup

```bash
cd app
docker build --build-arg APP_VERSION=local-test -t cloudops-app:local .
docker run -d --name test -p 5000:5000 cloudops-app:local
curl http://localhost:5000/health
docker stop test && docker rm test
```

## CI/CD Setup

### 1. Required GitHub repository Variables

Settings → Secrets and variables → Actions → **Variables** tab:

| Variable | Source |
|---|---|
| `AWS_ROLE_ARN` | `terraform output -raw github_actions_role_arn` |
| `AWS_REGION` | e.g. `us-east-1` |
| `ECR_REPOSITORY_URL` | `terraform output -raw ecr_repository_url` |
| `LAUNCH_TEMPLATE_ID` | `terraform output -raw launch_template_id` |
| `ASG_NAME` | `terraform output -raw asg_name` |
| `ALB_DNS_NAME` | `terraform output -raw alb_dns_name` |

Or via GitHub CLI:
```bash
gh variable set AWS_ROLE_ARN --body "$(terraform output -raw github_actions_role_arn)"
gh variable set AWS_REGION --body "us-east-1"
gh variable set ECR_REPOSITORY_URL --body "$(terraform output -raw ecr_repository_url)"
gh variable set LAUNCH_TEMPLATE_ID --body "$(terraform output -raw launch_template_id)"
gh variable set ASG_NAME --body "$(terraform output -raw asg_name)"
gh variable set ALB_DNS_NAME --body "$(terraform output -raw alb_dns_name)"
```

### 2. OIDC trust policy — why it's safe

The IAM role GitHub Actions assumes has a trust policy condition:
```
"token.actions.githubusercontent.com:sub": "repo:<org>/<repo>:ref:refs/heads/main"
```
Only workflows running on `main`, in this exact repository, can obtain
credentials — and those credentials expire within an hour and are scoped to
exactly two narrow IAM policies (ECR push to one repo; Launch
Template/ASG modification on two specific resources).

### 3. Pipeline behavior

- **CI** (`ci.yml`): runs `pytest` on every push and PR touching `app/**`;
  builds and pushes to ECR only on pushes to `main`.
- **CD** (`deploy.yml`): triggers automatically when CI succeeds on `main`;
  patches the Launch Template with the new image tag, triggers an Instance
  Refresh, verifies via `/version`, and rolls back automatically on any
  failure.

## Failure Simulation

See [`scripts/failure-test.sh`](../scripts/failure-test.sh) and
[`scripts/health-check.sh`](../scripts/health-check.sh). Run
`./scripts/health-check.sh <alb-dns>` in one terminal, then
`./scripts/failure-test.sh {terminate|break-app|cpu-load}` in another, one
test at a time, waiting for full recovery between each.

## Cost Management

| Resource | Approx. cost driver | Notes |
|---|---|---|
| NAT Gateway | ~$0.045/hr + data processing | Usually the largest single line item; `single_nat_gateway = true` (default) halves this vs. one-per-AZ |
| ALB | ~$0.0225/hr + LCU | Modest at low traffic |
| EC2 (2× t3.micro) | Instance-hours | May be free-tier eligible on a new account |
| ECR | ~$0.10/GB/month | Negligible with the lifecycle policy capping retained images |
| CloudWatch | ~$0.10/alarm/month + log ingestion | Negligible at this scale |

**Verify your own AWS account's free-tier eligibility** — do not assume this
project is free.

## Cleanup

```bash
cd terraform/environments/dev
terraform destroy
```

**What persists after `terraform destroy`:**
- The S3 state bucket itself (created outside Terraform in the bootstrap step)
- Any images already pushed to ECR are deleted along with the repository —
  if you want to preserve them, note the image digests first or copy them
  elsewhere before destroying
- CloudWatch log groups are deleted along with the rest of the stack (per the
  retention policy, not retained independently)

Re-running the full `terraform apply` from a clean slate recreates
everything except the state bucket, which only needs to be created once per
AWS account.
