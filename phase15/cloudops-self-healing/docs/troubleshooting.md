# Troubleshooting Guide

Organized by component. See each phase's original walkthrough for full
context; this is the consolidated quick-reference version.

## Terraform / State

- **`no valid credential sources`** — Run `aws configure` or set
  `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN`.
- **`Error acquiring the state lock`** — Another apply/plan is running, or a
  previous run crashed without releasing the lock. `terraform force-unlock
  <LOCK_ID>` if you're certain nothing else is running.
- **`Unsupported argument: use_lockfile`** — Terraform version predates 1.10;
  upgrade.
- **Unexpected diff on `user_data` after a CD deployment** — Confirm the
  compute module's `ignore_changes = [user_data]` (Phase 12) is present; the
  first `terraform apply` after any CD deployment reconciles once, which is
  expected.

## Networking

- **NAT Gateway stuck in `pending`** — Normal for a few minutes; check the
  AWS Health Dashboard if it exceeds ~5 minutes.
- **Private instances can't reach ECR/internet** — Check the private route
  table's default route actually points at the NAT Gateway (a per-AZ
  misconfiguration is the usual culprit if only one AZ is affected).

## Security Groups

- **EC2 SG shows a CIDR-based rule instead of a security-group reference**
  — Something bypassed the module; re-check `terraform plan` against the
  `security` module's `ec2_from_alb` rule.

## ECR

- **`no basic auth credentials`** — ECR login token expired (~12h) or wasn't
  run; re-run `aws ecr get-login-password | docker login ...`.
- **`ImageTagAlreadyExistsException`** — `IMMUTABLE` tagging correctly
  rejecting a tag reuse; push under a new tag.

## ALB / Target Group

- **`503` from the ALB** — Expected if no EC2 instances are registered yet
  (Phases 6-7) or all targets are currently unhealthy. Confirm via
  `aws elbv2 describe-target-health`.
- **Targets stuck in `initial` past the grace period** — Check the
  health-check path/port matches the container's actual listening port
  across every phase (Dockerfile `EXPOSE`, security group `app_port`, target
  group health check port).

## EC2 / Bootstrap

- **`docker ps` shows nothing after boot** — SSM in and check
  `/var/log/cloudops-bootstrap.log` first; usually an ECR auth failure (IAM
  role) or NAT routing issue.
- **SSM session fails with `TargetNotConnected`** — Agent hasn't registered
  yet (wait ~30-60s) or the instance can't reach the SSM endpoints (check NAT).

## Auto Scaling Group

- **Instance count never reaches desired capacity** — Check target health
  directly; a bootstrap failure on every new instance (bad image tag, broken
  IAM policy) will manifest as a permanently-`initial`/never-healthy loop.
- **CPU scaling policy seems inactive** — Target-tracking policies react
  conservatively by design; give it several minutes under sustained load.

## CloudWatch

- **No logs in the log group** — Confirm instances were launched *after*
  the Phase 9 log-shipping bootstrap script was deployed (old instances
  never had the `awslogs` driver configured); trigger an Instance Refresh.
- **Alarms stuck in `INSUFFICIENT_DATA`** — Normal for the first several
  minutes after creation.

## CI/CD

- **OIDC `Not authorized to perform sts:AssumeRoleWithWebIdentity`** —
  Trust policy `sub` condition doesn't match your actual `github_org`/
  `github_repo`/branch exactly (case-sensitive).
- **`EntityAlreadyExists` on the OIDC provider** — Your AWS account already
  has one from a prior project; set `create_github_oidc_provider = false`.
- **Deploy workflow's `sed` patch does nothing** — The `OLD_TAG` grep
  depends on the Phase 9+ bootstrap script's `APP_VERSION=` line existing on
  the currently-deployed instances; confirm they're running post-Phase-9
  user-data.
- **Deploy succeeds per AWS APIs but `/version` never matches** — The image
  built fine but crashes/misbehaves at runtime; SSM into a new instance and
  check `docker logs cloudops-app`. This is exactly the scenario the
  automatic rollback job exists for.
