# CloudOps — Self-Healing AWS Infrastructure

> A production-style, highly available, containerized web application on AWS —
> provisioned entirely with Terraform, deployed via GitHub Actions with OIDC
> authentication, and capable of automatically detecting and recovering from
> instance and application failure without human intervention.

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Problem Statement](#2-problem-statement)
3. [Architecture](#3-architecture)
4. [Technologies](#4-technologies)
5. [AWS Services](#5-aws-services)
6. [Infrastructure Diagram](#6-infrastructure-diagram)
7. [Repository Structure](#7-repository-structure)
8. [Prerequisites](#8-prerequisites)
9. [AWS Authentication Setup](#9-aws-authentication-setup)
10. [Terraform Deployment](#10-terraform-deployment)
11. [Docker Setup](#11-docker-setup)
12. [CI/CD Setup](#12-cicd-setup)
13. [Monitoring](#13-monitoring)
14. [Self-Healing Demonstration](#14-self-healing-demonstration)
15. [Failure-Testing Procedure](#15-failure-testing-procedure)
16. [Troubleshooting](#16-troubleshooting)
17. [Security Considerations](#17-security-considerations)
18. [Cost Considerations](#18-cost-considerations)
19. [Cleanup](#19-cleanup)
20. [Future Improvements](#20-future-improvements)
21. [Interview Preparation](docs/interview-prep.md)

---

## 1. Project Overview

CloudOps is a portfolio infrastructure project demonstrating a highly available,
self-healing web application deployment on AWS. A minimal Flask API runs in
Docker containers on EC2 instances managed by an Auto Scaling Group, sitting
behind an Application Load Balancer across two Availability Zones. The entire
stack — networking, security, compute, load balancing, monitoring, and CI/CD
authentication — is provisioned through modular Terraform. GitHub Actions
builds, tests, and deploys new versions automatically using short-lived OIDC
credentials, with zero long-lived AWS access keys anywhere in the pipeline.

The defining feature is genuine self-healing: if an EC2 instance is
terminated, or the application inside it crashes, the system detects the
failure via ALB health checks and the Auto Scaling Group replaces the
instance automatically — restoring full capacity without a human
provisioning a replacement server.

## 2. Problem Statement

Manually managed infrastructure has a recurring failure mode: a server goes
down, and recovery depends on someone noticing and manually intervening —
often at 2am, often slowly. This project addresses that by building
infrastructure that detects and recovers from common failure modes (instance
failure, application failure, and load spikes) on its own, using AWS-native
primitives rather than custom tooling — the same pattern used in real
production systems at much larger scale.

## 3. Architecture

**Traffic flow:**
```
Internet → ALB (public subnets, 2 AZs) → Target Group → EC2 instances
                                                          (private subnets, 2 AZs)
                                                          running Docker containers
                                                          pulled from ECR
```

**Deployment flow:**
```
git push → GitHub Actions CI (test, build, push to ECR with an immutable tag)
        → GitHub Actions CD (patch Launch Template, trigger Instance Refresh,
           verify via /version, roll back automatically on failure)
```

**Self-healing flow:**
```
ALB health check (GET /health) fails → Target Group marks instance unhealthy
→ ASG (health_check_type=ELB) detects it → terminates the unhealthy instance
→ launches a replacement from the Launch Template → bootstrap installs Docker,
  pulls the current image from ECR, starts the container → instance registers
  with the Target Group → health checks pass → traffic resumes
```

See [docs/architecture.md](docs/architecture.md) for the full breakdown of
every component, every security-group relationship, and the reasoning behind
each design decision made across the build.

## 4. Technologies

| Category | Choice |
|---|---|
| Application | Python 3.12, Flask, gunicorn |
| Containerization | Docker (non-root, slim base image) |
| Infrastructure as Code | Terraform (modular, S3 backend with native locking) |
| CI/CD | GitHub Actions, OIDC federation (no static AWS keys) |
| Testing | pytest |

## 5. AWS Services

| Service | Role |
|---|---|
| VPC, subnets, IGW, NAT Gateway | Network isolation — public subnets for ALB/NAT, private subnets for EC2 |
| Security Groups | Enforce that only the ALB can reach EC2, and only on the app port |
| Application Load Balancer | Public entry point, health checks, traffic distribution |
| Target Group | Tracks instance health for both the ALB and the ASG |
| Launch Template | Defines how every EC2 instance boots and bootstraps itself |
| Auto Scaling Group | Maintains desired capacity, replaces unhealthy instances, scales on CPU |
| Amazon ECR | Immutable, scanned container image registry |
| IAM (2 roles) | EC2 instance role (ECR pull, SSM, CloudWatch) and GitHub Actions OIDC role (ECR push, deploy) — least privilege, no static credentials |
| CloudWatch | Metrics, logs (via awslogs Docker driver), alarms, dashboard |
| SNS | Alarm notification delivery |
| Systems Manager (Session Manager) | Shell access without SSH or open port 22 |

## 6. Infrastructure Diagram

See [architecture/architecture.mmd](architecture/architecture.mmd) (Mermaid
source, renders natively on GitHub) or the rendered version in
[docs/architecture.md](docs/architecture.md).

## 7. Repository Structure

```
cloudops-self-healing/
├── app/                       # Flask application + tests + Dockerfile
├── terraform/
│   ├── modules/                # networking, security, ecr, alb, compute,
│   │                            # autoscaling, monitoring, github_oidc
│   └── environments/dev/       # Environment composition
├── .github/workflows/          # ci.yml (test/build/push), deploy.yml (CD)
├── scripts/                    # bootstrap.sh, health-check.sh, failure-test.sh
├── docs/                       # architecture, deployment, troubleshooting, DR
└── architecture/               # architecture.mmd (diagram source)
```

## 8. Prerequisites

- An AWS account with sufficient permissions to create IAM roles, VPC
  resources, EC2/ASG/ALB resources, ECR repositories, and CloudWatch resources
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.10
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) v2, configured (`aws configure`)
- Docker (Desktop or Engine)
- A GitHub account and a fork/clone of this repository
- [GitHub CLI](https://cli.github.com/) (optional, used in setup commands below)
- `jq` (used by several scripts)

## 9. AWS Authentication Setup

Local/Terraform access uses your own AWS CLI credentials (`aws configure` or
SSO) — never commit these. CI/CD access uses GitHub Actions OIDC federation —
see [docs/deployment.md](docs/deployment.md#cicd-setup) for the full trust
policy explanation and setup steps. No AWS access keys are ever stored in
GitHub.

## 10. Terraform Deployment

Full step-by-step instructions, including the one-time S3 state bucket
bootstrap, are in [docs/deployment.md](docs/deployment.md#terraform-deployment).
Quick reference:

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars   # edit with your values
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## 11. Docker Setup

```bash
cd app
docker build --build-arg APP_VERSION=local-test -t cloudops-app:local .
docker run -d -p 5000:5000 cloudops-app:local
curl http://localhost:5000/health
```

See [app/Dockerfile](app/Dockerfile) for the full image definition and
inline rationale for each decision (non-root user, slim base, healthcheck).

## 12. CI/CD Setup

See [docs/deployment.md](docs/deployment.md#cicd-setup) for the full OIDC
trust-policy walkthrough and the list of required GitHub repository
Variables (`AWS_ROLE_ARN`, `AWS_REGION`, `ECR_REPOSITORY_URL`,
`LAUNCH_TEMPLATE_ID`, `ASG_NAME`, `ALB_DNS_NAME`).

## 13. Monitoring

A CloudWatch dashboard (`terraform output dashboard_url`) provides
single-screen visibility into request count, 4xx/5xx rates, target health,
CPU utilization, in-service instance count, and recent application logs.
Four alarms notify via SNS on: ALB 5xx spikes, unhealthy targets, sustained
high CPU, and in-service instance count dropping below the configured
minimum. Full rationale for each metric/threshold/action in
[docs/architecture.md](docs/architecture.md#monitoring-design).

## 14. Self-Healing Demonstration

<FILL IN: paste your actual Phase 8/10 target-health output and/or a
screenshot here — e.g. `aws elbv2 describe-target-health` output showing
2 healthy targets, and a screenshot of the CloudWatch dashboard during a
live failure test.>

## 15. Failure-Testing Procedure

Three controlled failure simulations, automated via
[`scripts/failure-test.sh`](scripts/failure-test.sh):

| Test | Command | What it proves |
|---|---|---|
| Instance termination | `./scripts/failure-test.sh terminate` | ASG detects and replaces a hard-terminated instance |
| Application failure | `./scripts/failure-test.sh break-app` | ALB `ELB` health checks (not just EC2 status checks) catch an app-level failure |
| High CPU / scale-out | `./scripts/failure-test.sh cpu-load` | Target-tracking scaling policy adds capacity under load |

**Actual observed results from this project:**

<FILL IN: paste real elapsed-time numbers from your own Phase 10 run here,
e.g. "Test 1: 2 healthy targets restored in ~128s (see
`aws autoscaling describe-scaling-activities` output below)." Do not
estimate — use the real `StartTime`/`EndTime` values from the AWS CLI
output, as described in Phase 10's verification section.>

Full procedure, expected output, and troubleshooting: see the Phase 10
walkthrough in [docs/deployment.md](docs/deployment.md#failure-simulation).

## 16. Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for a consolidated,
searchable list of every issue encountered across all phases of this build,
organized by component.

## 17. Security Considerations

- No SSH; access via AWS Systems Manager Session Manager only
- EC2 instances in private subnets with no public IPs
- Security groups: EC2 ingress restricted to the ALB security group only
  (not a CIDR block)
- IAM least privilege throughout: EC2 instance role scoped to one ECR repo;
  GitHub Actions OIDC role scoped to one ECR repo, one Launch Template, one ASG
- No static AWS credentials anywhere — EC2 uses an instance role, CI/CD uses
  OIDC federation with a `sub` claim pinned to this repository's `main` branch
- IMDSv2 enforced on all EC2 instances
- EBS volumes encrypted at rest; ECR encrypted at rest
- ECR image scanning on push; `IMMUTABLE` tags (no `latest`-only deploys)
- **Intentional simplifications for this learning project** (see
  [docs/architecture.md](docs/architecture.md#security-tradeoffs) for full
  reasoning): HTTP-only by default (HTTPS/ACM structure is present but
  requires a real domain to enable); egress security-group rules left open
  rather than restricted to specific AWS service endpoints; no WAF.

## 18. Cost Considerations

The NAT Gateway and ALB are the two dominant fixed hourly costs; EC2
(2× t3.micro) may be free-tier eligible on a new account. Full cost
breakdown, a low-cost dev configuration (`single_nat_gateway = true`,
already the default), and guidance on what's safe to leave running vs. what
to tear down between sessions: see
[docs/deployment.md](docs/deployment.md#cost-management).

**This project does not qualify as free** unless your AWS account is within
its free-tier window and usage stays within free-tier limits — verify your
own account's status rather than relying on this statement.

## 19. Cleanup

```bash
cd terraform/environments/dev
terraform destroy
```

Full walkthrough, including what does and doesn't get destroyed
automatically (the S3 state bucket and ECR images persist by design), is in
[docs/deployment.md](docs/deployment.md#cleanup).

## 20. Future Improvements

- HTTPS via ACM + a real domain, with the HTTP listener redirecting to HTTPS
  (structure already present, disabled by default)
- Blue/green or canary deployment instead of rolling Instance Refresh
- Multi-region disaster recovery
- WAF in front of the ALB
- Egress security-group restriction to specific AWS service endpoints
- Automated load testing as part of the CI/CD pipeline
- Terraform remote state locking failure alerting

## License

MIT — see [LICENSE](LICENSE)
