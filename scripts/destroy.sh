#!/usr/bin/env bash
# =============================================================================
# scripts/destroy.sh — one-command teardown
#
# RDS has deletion_protection = true on purpose, so destroy is a two-step:
#   1. Disable deletion protection on the RDS instance via AWS CLI
#   2. Run terraform destroy
#
# Usage:    bash scripts/destroy.sh
# Or:       make destroy
# =============================================================================

set -euo pipefail

REGION="${AWS_REGION:-eu-central-1}"
PROJECT="${PROJECT:-frank-cloudprog}"
ENV="${ENV:-dev}"
DB_ID="${PROJECT}-${ENV}-db"

echo "=== Step 1/2: disabling RDS deletion protection on $DB_ID ==="
if aws rds describe-db-instances \
     --db-instance-identifier "$DB_ID" \
     --region "$REGION" >/dev/null 2>&1; then
  aws rds modify-db-instance \
    --db-instance-identifier "$DB_ID" \
    --no-deletion-protection \
    --apply-immediately \
    --region "$REGION" >/dev/null
  echo "  Deletion protection disabled."
else
  echo "  RDS instance not found — skipping (nothing to disable)."
fi
echo ""

echo "=== Step 2/2: terraform destroy ==="
terraform destroy -auto-approve
echo ""

echo "=== Post-destroy verification ==="
echo "  NAT Gateways still running:"
aws ec2 describe-nat-gateways --region "$REGION" \
  --filter "Name=state,Values=available" \
  --query 'NatGateways[*].NatGatewayId' --output text || true
echo ""
echo "  RDS instances:"
aws rds describe-db-instances --region "$REGION" \
  --query 'DBInstances[*].DBInstanceIdentifier' --output text || true
echo ""
echo "Done. If both lines above are empty, you are no longer being billed."
