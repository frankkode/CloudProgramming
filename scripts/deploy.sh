#!/usr/bin/env bash
# =============================================================================
# scripts/deploy.sh — one-command deploy
#
# Walks through the full deployment from a clean checkout:
#   1. Verifies prerequisites (terraform, aws CLI, AWS credentials)
#   2. Initialises Terraform if needed
#   3. Validates the configuration
#   4. Generates a plan
#   5. Applies the plan
#   6. Prints the outputs
#   7. Runs the verify smoke test
#
# Usage:    bash scripts/deploy.sh
# Or:       make apply && make verify
# =============================================================================

set -euo pipefail

REGION="${AWS_REGION:-eu-central-1}"

# --- Pre-flight --------------------------------------------------------------
echo "=== Pre-flight checks ==="
for cmd in terraform aws curl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERROR: $cmd is not installed"
    exit 1
  fi
done

if ! aws sts get-caller-identity --region "$REGION" >/dev/null 2>&1; then
  echo "ERROR: AWS credentials not configured. Run: aws configure"
  exit 1
fi

if [ ! -f terraform.tfvars ]; then
  echo "ERROR: terraform.tfvars not found. Run: cp terraform.tfvars.example terraform.tfvars"
  echo "       then set db_password (>= 8 chars)."
  exit 1
fi

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
USER=$(aws sts get-caller-identity --query Arn --output text)
echo "  AWS account : $ACCOUNT"
echo "  Caller ARN  : $USER"
echo "  Region      : $REGION"
echo ""

# --- Init --------------------------------------------------------------------
echo "=== terraform init ==="
terraform init
echo ""

# --- Validate ----------------------------------------------------------------
echo "=== terraform validate ==="
terraform validate
echo ""

# --- Plan --------------------------------------------------------------------
echo "=== terraform plan ==="
terraform plan -out=plan.tfplan
echo ""

# --- Apply -------------------------------------------------------------------
echo "=== terraform apply ==="
echo "This will take ~15-20 minutes (CloudFront propagation is the slow part)."
terraform apply plan.tfplan
echo ""

# --- Outputs -----------------------------------------------------------------
echo "=== Outputs ==="
terraform output alb_url
terraform output cloudfront_url
echo ""

# --- Smoke test --------------------------------------------------------------
echo "=== Smoke test ==="
echo "Waiting 60 s for the ASG instances to register as healthy..."
sleep 60
bash scripts/verify.sh
