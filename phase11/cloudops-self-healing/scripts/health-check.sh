#!/bin/bash
# ---------------------------------------------------------------------------
# health-check.sh — continuously polls the ALB and prints which instance
# (by hostname) answered each request, with a timestamp.
#
# Run this in its own terminal window WHILE running failure-test.sh in
# another — it's your live view of the self-healing process happening.
#
# Usage:
#   ./scripts/health-check.sh <alb-dns-name> [interval-seconds]
#
# Example:
#   ./scripts/health-check.sh cloudops-dev-alb-123456.us-east-1.elb.amazonaws.com 3
# ---------------------------------------------------------------------------

set -euo pipefail

ALB_DNS="${1:?Usage: $0 <alb-dns-name> [interval-seconds]}"
INTERVAL="${2:-3}"

echo "Polling http://${ALB_DNS}/health every ${INTERVAL}s — Ctrl+C to stop"
echo "-----------------------------------------------------------------"

while true; do
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  RESPONSE=$(curl -s -o /tmp/health_response.json -w "%{http_code}" \
    --max-time 5 "http://${ALB_DNS}/health" || echo "000")

  if [ "$RESPONSE" == "200" ]; then
    HOSTNAME=$(jq -r '.hostname // "unknown"' /tmp/health_response.json 2>/dev/null || echo "unparseable")
    echo "[$TIMESTAMP] HTTP $RESPONSE  <-  $HOSTNAME"
  else
    echo "[$TIMESTAMP] HTTP $RESPONSE  <-  (no healthy target reached)"
  fi

  sleep "$INTERVAL"
done
