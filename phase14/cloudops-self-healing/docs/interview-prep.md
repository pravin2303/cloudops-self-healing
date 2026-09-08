# Interview Preparation

## Resume-Ready Project Description

> Designed and deployed a self-healing, highly available AWS infrastructure
> for a containerized Flask application, using Terraform (8 reusable
> modules), Docker, an Application Load Balancer, and an Auto Scaling Group
> across 2 Availability Zones. Implemented a GitHub Actions CI/CD pipeline
> authenticated via OIDC federation (zero long-lived AWS credentials) that
> builds, tests, deploys, and automatically rolls back failed releases.
> Configured CloudWatch monitoring with 4 operationally meaningful alarms
> and validated automatic failure recovery through controlled fault
> injection (instance termination, application crash, and CPU-load
> scaling tests).

Adjust the specifics (module count, AZ count, alarm count) if you change
the project after this point — don't let the resume drift out of sync with
what you actually built.

---

## Beginner Questions

### What is Terraform?

Terraform is an Infrastructure-as-Code tool — you describe the AWS
resources you want (a VPC, a load balancer, an Auto Scaling Group) in
configuration files, and Terraform figures out what API calls are needed to
make reality match that description. In this project, every single AWS
resource — from the VPC down to the CloudWatch alarms — is defined in
`.tf` files, so the entire infrastructure can be recreated identically with
`terraform apply`, or torn down completely with `terraform destroy`. Nothing
was clicked into existence in the AWS Console.

### What is an Auto Scaling Group?

An ASG is AWS's mechanism for keeping a specified number of EC2 instances
running automatically. You tell it a minimum, desired, and maximum count
(in this project: 2, 2, and 4), and it launches or terminates instances to
match — including replacing instances that fail health checks, which is the
actual self-healing mechanism in this project.

### What is an ALB?

An Application Load Balancer distributes incoming HTTP traffic across
multiple backend targets (in this project, EC2 instances) and continuously
health-checks each one. It's also the only public-facing entry point in
this architecture — everything else lives in private subnets.

### What is ECR?

Elastic Container Registry is AWS's private Docker image registry — like
Docker Hub, but private to your AWS account and integrated with IAM for
access control. This project pushes every built image to ECR with an
immutable tag, and EC2 instances pull from ECR using their IAM role instead
of a username/password.

### What is CloudWatch?

CloudWatch is AWS's monitoring service — it collects metrics (like CPU
usage or request counts), stores logs, and can trigger alarms when a metric
crosses a threshold. In this project it powers the operational dashboard,
ships application logs, and fires 4 alarms (ALB 5xx errors, unhealthy
targets, high CPU, low instance count) to an SNS topic.

### Why Docker?

Docker packages the application with everything it needs to run
(dependencies, Python runtime, exact versions) into one portable image. The
same image that passes tests in CI is the exact same image that runs in
production — eliminating "it worked on my machine" failures. It also
enables the immutable-versioning story: every deployed version is a
specific, addressable image tag.

---

## Intermediate Questions

### How does self-healing work?

Three things have to be true simultaneously: (1) the ALB health-checks
`/health` on every instance and marks failures at the Target Group level,
(2) the Auto Scaling Group is configured with `health_check_type = "ELB"`
instead of the AWS default `EC2`, meaning it asks the ALB "is this instance
healthy?" rather than only checking EC2-level hardware status, and (3) when
the ASG sees an unhealthy target, it terminates that instance and launches
a replacement from the same Launch Template — which bootstraps itself
(installs Docker, pulls the image from ECR, starts the container) with zero
human involvement. I proved this works with three controlled tests: hard
instance termination, stopping the application container while leaving the
instance alive, and sustained CPU load to trigger scale-out.

### How does ALB health checking work?

The ALB sends a `GET /health` request to each registered target on a fixed
interval (15 seconds in this project) and expects an HTTP 200. After 2
consecutive successes, a target is marked healthy and receives traffic;
after 2 consecutive failures, it's marked unhealthy and the ALB immediately
stops routing to it — before the ASG even decides whether to replace the
instance.

### How does Auto Scaling replace instances?

The ASG continuously compares its actual instance count and health status
against its configured desired capacity and health check type. If an
instance is terminated externally, or marked unhealthy by the ALB, the ASG's
own control loop notices the discrepancy and calls the EC2 API to launch a
replacement from the Launch Template — same AMI, same IAM role, same
bootstrap script, every time.

### Why use Launch Templates?

A Launch Template is the reusable "recipe" for how to launch an EC2
instance — AMI, instance type, security group, IAM role, and bootstrap
script, all versioned. The ASG references it instead of instance
configuration being hardcoded anywhere, which means updating the deployed
application version is just: create a new Launch Template version with an
updated image tag, and tell the ASG to refresh onto it — no manual
instance-by-instance changes.

### Why use private subnets?

Defense in depth: EC2 instances have no public IP address and are not
directly reachable from the internet at all — only the ALB is. Even if
someone found the application's port, there's no route to it except through
the ALB, and the ALB only forwards traffic that passed its health check
logic. This also means a compromised instance can't be used to pivot
directly from the internet.

### How does GitHub Actions authenticate with AWS?

Via OIDC federation, not stored credentials. When a workflow runs, GitHub's
own OIDC provider issues a short-lived signed token scoped to that specific
workflow run. The `aws-actions/configure-aws-credentials` action presents
that token to AWS STS, which validates it against a registered OIDC
provider and an IAM role's trust policy — checking that the token's `sub`
claim matches exactly `repo:<org>/<repo>:ref:refs/heads/main`. If it
matches, STS issues temporary AWS credentials (max 1 hour) scoped to that
role's permissions. Nothing is stored in GitHub at any point.

### Why OIDC instead of access keys?

Static access keys stored as GitHub secrets are a long-lived, high-value
target — if leaked (via a compromised dependency, a misconfigured log, a
malicious PR from a fork), they're valid until someone notices and manually
rotates them. OIDC-issued credentials expire automatically within the hour
and are cryptographically tied to a specific repository and branch — there
is no long-lived secret to leak in the first place.

### How does Terraform manage state?

Terraform keeps a state file mapping every resource in your config to the
real AWS resource it created (by ID). This project stores that state
remotely in an S3 bucket (not locally, so it's shared and durable) with
versioning enabled for recovery, and uses Terraform's native S3 locking
(`use_lockfile`, Terraform 1.10+) to prevent two people/processes from
running `apply` concurrently and corrupting each other's changes — the
modern replacement for the older DynamoDB-table locking pattern.

---

## Advanced Questions

### What happens if an Availability Zone fails?

With instances split across 2 AZs and a minimum capacity of 2, losing one
AZ still leaves the other AZ's instance serving traffic — the ALB simply
stops routing to targets in the failed AZ. The ASG will attempt to launch
replacement capacity, though if that specific AZ is the one experiencing
the outage, replacement launches there may also fail until AWS resolves it.
One real gap I documented: with the default `single_nat_gateway = true`
cost-saving setting, the NAT Gateway lives in only one AZ — if that
specific AZ fails, private subnets in *both* AZs lose outbound internet
access, not just the affected one. The fix is `single_nat_gateway = false`
(one NAT Gateway per AZ), at roughly double the NAT cost — a trade-off I
made deliberately and documented rather than hid.

### What happens during a failed deployment?

The CD pipeline's last step polls the live `/version` endpoint until it
matches the newly-deployed tag, with a timeout. If it never matches — say,
the image built and passed tests but crashes at runtime — that step fails,
which triggers an automatic rollback job: it resets the Launch Template's
default version back to whatever was running before this deployment, and
triggers another Instance Refresh to roll back. Recovery starts within
seconds of the failed verification, with no human needing to notice first.

### How would you implement blue/green deployment?

Currently this project uses a rolling Instance Refresh — instances are
replaced gradually within the same ASG. A true blue/green setup would
instead stand up a second, fully separate ASG + Target Group running the
new version alongside the old one, verify it's healthy, then shift the
ALB's listener to point at the new Target Group all at once (or via
weighted routing for a canary-style gradual shift), and only then tear down
the old ASG. AWS CodeDeploy has native blue/green support for ASGs that
would fit here well; alternatively, this could be built directly with two
Terraform-managed ASG/Target Group pairs and a listener rule swap.

### How would you implement HTTPS?

The ALB module already has the structure for this (`enable_https`,
`acm_certificate_arn` variables, a conditional HTTPS listener) — it's just
disabled by default because it requires a registered domain. To enable it:
register a domain, request a certificate via AWS Certificate Manager
(validated via DNS), point the domain at the ALB via a Route 53 alias
record, then set `enable_https = true` with the certificate's ARN — the
Terraform will then also flip the HTTP listener to redirect to HTTPS
instead of forwarding directly.

### How would you reduce NAT Gateway costs?

A few options, in order of how much they change the architecture: (1) keep
`single_nat_gateway = true`, the trade-off already made here; (2) use a NAT
instance instead of a managed NAT Gateway — cheaper but requires you to
manage patching/HA yourself, which somewhat defeats the point of a managed
service; (3) add VPC Interface Endpoints for the specific AWS services
instances actually talk to (ECR, S3, CloudWatch Logs, SSM) — traffic to
those endpoints stays on the AWS network entirely and never needs the NAT
Gateway at all, which could eliminate most of this project's NAT traffic
since ECR pulls are the dominant outbound use case.

### How would you prevent an unhealthy AMI/container from propagating?

This project already has two layers: ECR's `IMMUTABLE` tag policy prevents
silently overwriting a "good" tag with bad content, and the CD pipeline's
`/version` verification step catches a broken deployment before declaring
success — triggering automatic rollback. To go further, I'd add a canary
step: deploy the new version to a small subset of instances first (or a
separate small ASG), run automated smoke tests against just that subset,
and only proceed to a full Instance Refresh if those pass — rather than
rolling out to all instances immediately and discovering a problem only
after the fact.

### How would you improve observability?

Current setup covers infrastructure metrics and basic logs well; I'd add:
distributed tracing (AWS X-Ray) to see request-level latency breakdowns
inside the Flask app itself, not just ALB-level aggregate metrics;
structured JSON logging instead of gunicorn's default access-log format, to
make CloudWatch Logs Insights queries more precise; and a synthetic
canary (CloudWatch Synthetics) hitting `/health` from outside the AWS
network entirely, to catch failures the ALB's own health check — which
only tests from inside AWS's infrastructure — might miss (e.g., a DNS
misconfiguration or an internet-routing issue affecting real users).

### How would you implement multi-region disaster recovery?

This project is single-region by design (appropriate for its scope). A
real multi-region setup would need: the Terraform modules duplicated per
region (they're already parameterized enough to support this — `aws_region`
is a variable throughout), ECR set up with cross-region replication so
images don't need separate pushes per region, Route 53 with health-check-
based failover routing (or latency-based routing for active-active) pointing
at each region's ALB, and — the hard part — a strategy for any stateful data
(this app is stateless today, so this specific project sidesteps that
problem, but any real app usually isn't). I'd also need to decide
active-passive (cheaper, simpler, slower failover) vs. active-active (more
expensive, always-on capacity in both regions, faster failover) based on
actual RTO/RPO requirements — not by default.
