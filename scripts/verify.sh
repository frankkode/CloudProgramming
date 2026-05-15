#!/usr/bin/env bash
# =============================================================================
# scripts/verify.sh — post-deploy smoke test
#
# Reads the ALB URL from `terraform output`, hits it 20 times, and confirms
# that requests are served from BOTH Availability Zones. Exits 0 on success,
# 1 on failure (suitable for CI).
#
# Usage:    bash scripts/verify.sh
# Or:       make verify
# =============================================================================

set -euo pipefail

# --- Pre-flight --------------------------------------------------------------
if ! command -v terraform >/dev/null 2>&1; then
  echo "ERROR: terraform not on PATH"
  exit 1
fi
if ! command -v curl >/dev/null 2>&1; then
  echo "ERROR: curl not on PATH"
  exit 1
fi
if [ ! -f terraform.tfstate ] && [ ! -f .terraform/terraform.tfstate ]; then
  echo "ERROR: no Terraform state found. Did you run 'terraform apply' yet?"
  exit 1
fi

# --- Resolve the ALB URL -----------------------------------------------------
ALB_URL=$(terraform output -raw alb_url 2>/dev/null || echo "")
if [ -z "$ALB_URL" ]; then
  echo "ERROR: terraform output alb_url returned empty. Is the stack deployed?"
  exit 1
fi
echo "Probing $ALB_URL ..."

# --- 20 sequential requests, count distinct AZs ------------------------------
declare -A SEEN
N=20
for i in $(seq 1 "$N"); do
  AZ=$(curl -sS --max-time 5 "$ALB_URL" 2>/dev/null \
        | grep -oE "eu-central-1[a-z]" | head -n 1 || true)
  if [ -n "$AZ" ]; then
    SEEN[$AZ]=$((${SEEN[$AZ]:-0} + 1))
    printf "  [%2d/%d] served by %s\n" "$i" "$N" "$AZ"
  else
    printf "  [%2d/%d] no AZ in response (instance may still be initialising)\n" "$i" "$N"
  fi
  sleep 0.2
done

# --- Verdict -----------------------------------------------------------------
echo ""
echo "Distribution across AZs:"
for AZ in "${!SEEN[@]}"; do
  printf "  %s : %d requests\n" "$AZ" "${SEEN[$AZ]}"
done

if [ "${#SEEN[@]}" -ge 2 ]; then
  echo ""
  echo "PASS: requests served from ${#SEEN[@]} different Availability Zones."
  exit 0
else
  echo ""
  echo "FAIL: only ${#SEEN[@]} AZ(s) responded. Cross-AZ load balancing not demonstrated."
  echo "      Possible causes: one instance is unhealthy, sticky sessions, or CloudFront cache."
  exit 1
fi
