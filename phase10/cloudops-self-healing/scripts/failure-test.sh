#!/bin/bash
# ---------------------------------------------------------------------------
# failure-test.sh — automates the three controlled failure simulations
# from the project plan. Each test prints timestamps at every observed
# state change so you have real, specific numbers — not estimates.
#
# Usage:
#   ./scripts/failure-test.sh terminate    # Test 1 — instance termination
#   ./scripts/failure-test.sh break-app    # Test 2 — application failure
#   ./scripts/failure-test.sh cpu-load     # Test 3 — high CPU / scale-out
#
# Requires: ASG_NAME and TARGET_GROUP_ARN environment variables set
# (both available via `terraform output` in terraform/environments/dev).
# ---------------------------------------------------------------------------

set -euo pipefail

ASG_NAME="${ASG_NAME:?Set ASG_NAME=$(terraform output -raw asg_name)}"
TARGET_GROUP_ARN="${TARGET_GROUP_ARN:?Set TARGET_GROUP_ARN=$(terraform output -raw target_group_arn)}"

now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

get_healthy_count() {
  aws elbv2 describe-target-health \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" \
    --output text
}

get_in_service_instances() {
  aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "AutoScalingGroups[0].Instances[?LifecycleState=='InService'].InstanceId" \
    --output text
}

wait_for_healthy_count() {
  local expected="$1"
  local timeout_s="${2:-300}"
  local elapsed=0
  while [ "$(get_healthy_count)" -lt "$expected" ]; do
    if [ "$elapsed" -ge "$timeout_s" ]; then
      echo "[$(now)] TIMEOUT waiting for $expected healthy targets after ${timeout_s}s"
      return 1
    fi
    sleep 10
    elapsed=$((elapsed + 10))
    echo "[$(now)] ... still waiting (healthy: $(get_healthy_count)/$expected, elapsed: ${elapsed}s)"
  done
  echo "[$(now)] Recovered: $expected healthy targets (took ~${elapsed}s)"
}

# ---------------------------------------------------------------------------
# Test 1 — EC2 instance termination
# ---------------------------------------------------------------------------
test_terminate() {
  echo "=== Test 1: EC2 Instance Termination ==="
  local before_count
  before_count=$(get_healthy_count)
  echo "[$(now)] Healthy targets before test: $before_count"

  local instances
  instances=$(get_in_service_instances)
  local target_instance
  target_instance=$(echo "$instances" | awk '{print $1}')

  echo "[$(now)] Terminating instance: $target_instance"
  aws ec2 terminate-instances --instance-ids "$target_instance" > /dev/null

  echo "[$(now)] Waiting for ASG to detect and replace it..."
  sleep 20 # let AWS register the termination before we start polling
  wait_for_healthy_count "$before_count" 300

  echo "[$(now)] Test 1 complete. Verify with:"
  echo "  aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $ASG_NAME --query 'AutoScalingGroups[0].Instances'"
}

# ---------------------------------------------------------------------------
# Test 2 — Application failure (container stopped, instance stays alive)
# ---------------------------------------------------------------------------
test_break_app() {
  echo "=== Test 2: Application Failure ==="
  local before_count
  before_count=$(get_healthy_count)
  echo "[$(now)] Healthy targets before test: $before_count"

  local instances
  instances=$(get_in_service_instances)
  local target_instance
  target_instance=$(echo "$instances" | awk '{print $1}')

  echo "[$(now)] Stopping the application container on instance: $target_instance (instance itself stays running)"
  local command_id
  command_id=$(aws ssm send-command \
    --instance-ids "$target_instance" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=["docker stop cloudops-app"]' \
    --query "Command.CommandId" --output text)

  sleep 5
  aws ssm get-command-invocation \
    --command-id "$command_id" --instance-id "$target_instance" \
    --query '{Status:Status,Output:StandardOutputContent}'

  echo "[$(now)] Application stopped. Waiting for ALB to detect the failure and the ASG to replace the instance..."
  echo "[$(now)] (Note: the ASG replaces the whole instance here, not just the container —"
  echo "         the container isn't restarted in place because health_check_type=ELB"
  echo "         means the ASG treats a failed target as an instance-level problem.)"

  wait_for_healthy_count "$before_count" 400

  echo "[$(now)] Test 2 complete."
}

# ---------------------------------------------------------------------------
# Test 3 — High CPU / scale-out
# ---------------------------------------------------------------------------
test_cpu_load() {
  echo "=== Test 3: High CPU / Scale-Out ==="
  local before_desired
  before_desired=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --query "AutoScalingGroups[0].DesiredCapacity" --output text)
  echo "[$(now)] Desired capacity before test: $before_desired"

  local instances
  instances=$(get_in_service_instances)
  echo "[$(now)] Generating sustained CPU load on all in-service instances: $instances"

  for instance in $instances; do
    aws ssm send-command \
      --instance-ids "$instance" \
      --document-name "AWS-RunShellScript" \
      --parameters 'commands=["for i in $(seq 1 $(nproc)); do (yes > /dev/null &) ; done", "echo load started"]' \
      --query "Command.CommandId" --output text > /dev/null
  done

  echo "[$(now)] Load generators started. Monitoring CPUUtilization and desired capacity every 30s for up to 10 minutes..."
  local elapsed=0
  local scaled=false
  while [ "$elapsed" -lt 600 ]; do
    local current_desired
    current_desired=$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "$ASG_NAME" \
      --query "AutoScalingGroups[0].DesiredCapacity" --output text)
    echo "[$(now)] Desired capacity: $current_desired (elapsed: ${elapsed}s)"
    if [ "$current_desired" -gt "$before_desired" ]; then
      echo "[$(now)] Scale-out detected: $before_desired -> $current_desired"
      scaled=true
      break
    fi
    sleep 30
    elapsed=$((elapsed + 30))
  done

  if [ "$scaled" = false ]; then
    echo "[$(now)] No scale-out observed within 10 minutes — check the CloudWatch dashboard / alarm state."
  fi

  echo "[$(now)] Cleaning up load generators on original instances..."
  for instance in $instances; do
    aws ssm send-command \
      --instance-ids "$instance" \
      --document-name "AWS-RunShellScript" \
      --parameters 'commands=["pkill -f \"yes\" || true", "echo load stopped"]' \
      --query "Command.CommandId" --output text > /dev/null
  done

  echo "[$(now)] Test 3 load generation stopped. The ASG will scale back in on its own over the"
  echo "         next several minutes once average CPU drops back below the 60% target — this is"
  echo "         expected to take longer than scale-out, by design (AWS default scale-in cooldown"
  echo "         behavior avoids flapping)."
}

case "${1:-}" in
  terminate)  test_terminate ;;
  break-app)  test_break_app ;;
  cpu-load)   test_cpu_load ;;
  *)
    echo "Usage: $0 {terminate|break-app|cpu-load}"
    exit 1
    ;;
esac
