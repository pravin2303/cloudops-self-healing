# Disaster Recovery

## Scope

This document covers recovery from failures beyond the automatic
self-healing this project already handles (single-instance failure,
application crashes, and load spikes — see the main README's Self-Healing
section). It addresses scenarios requiring human intervention.

## Scenario: Availability Zone failure

**Impact:** With 2 AZs configured, losing one AZ removes roughly half of
running capacity. The ASG will attempt to launch replacement instances — if
the affected AZ's subnet is still creatable-into but degraded, or if AWS
itself is experiencing an AZ-level outage, replacements may fail to launch
in that AZ specifically.

**Recovery:**
1. Check `aws autoscaling describe-scaling-activities` for launch failures
   specific to one AZ.
2. If the affected AZ is confirmed down (AWS Health Dashboard), the ASG will
   continue trying that AZ per its configured subnets — consider temporarily
   editing the ASG's `vpc_zone_identifier` (via a targeted Terraform change)
   to exclude the affected AZ's subnet until AWS resolves the outage, then
   revert.
3. With `single_nat_gateway = true` (the default), losing the AZ containing
   the NAT Gateway breaks outbound connectivity for *all* private subnets,
   not just that AZ's — this is the concrete cost of the single-NAT
   cost-saving trade-off documented in Phase 3. Switching to
   `single_nat_gateway = false` (one NAT Gateway per AZ) removes this
   single point of failure at roughly double the NAT cost.

## Scenario: Bad deployment reaches production despite CI passing

**Impact:** A change passes tests and builds successfully but fails at
runtime (e.g., a missing environment-dependent behavior CI didn't catch).

**Recovery:** The Phase 12 CD pipeline's verification step (`/version`
polling) and automatic rollback job are the first line of defense — a
deployment that doesn't verify within the timeout triggers an automatic
revert to the previous Launch Template version with no human action
required. If a bad version somehow verifies successfully but misbehaves
under real traffic later:
```bash
# Manually revert to a known-good Launch Template version
aws ec2 modify-launch-template \
  --launch-template-id <id> --default-version <known-good-version>

aws autoscaling start-instance-refresh \
  --auto-scaling-group-name <asg-name> \
  --preferences '{"MinHealthyPercentage": 50, "InstanceWarmup": 90}'
```

## Scenario: Terraform state corruption or loss

**Impact:** State file corrupted, accidentally deleted, or force-unlocked
incorrectly mid-operation.

**Recovery:** S3 versioning is enabled on the state bucket (Phase 3
bootstrap) — restore the previous version:
```bash
aws s3api list-object-versions --bucket <state-bucket> --prefix cloudops-self-healing/dev/terraform.tfstate
aws s3api get-object --bucket <state-bucket> --key cloudops-self-healing/dev/terraform.tfstate \
  --version-id <version-id> terraform.tfstate.recovered
```
As a last resort, `terraform import` can rebuild state resource-by-resource
against the actual running infrastructure, though this is significantly
more time-consuming.

## Scenario: Full environment loss / rebuild from scratch

Given everything is codified in Terraform and the application image lives
in ECR, full rebuild is:
```bash
cd terraform/environments/dev
terraform apply   # recreates VPC through monitoring, ~10-15 minutes total
```
Assuming the S3 state bucket and ECR repository/images still exist. If ECR
images were also lost, the CI pipeline can rebuild and push a fresh image
from the last known-good commit.

## Recovery Time Expectations

<FILL IN: after running the Phase 10 failure simulations and any real
incidents, record your own observed recovery times here — e.g. "single
instance replacement: observed Xs in testing." Do not use estimated or
industry-standard figures; use only what you've actually measured on this
specific deployment.>
