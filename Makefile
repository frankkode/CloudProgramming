# =============================================================================
# CloudProgramming — Highly Available Web App on AWS
# Common Make targets. Run `make help` for a full list.
# =============================================================================

# --- Configuration -----------------------------------------------------------
REGION       ?= eu-central-1
PROJECT      ?= frank-cloudprog
ENV          ?= dev
DB_ID        := $(PROJECT)-$(ENV)-db
ASG_NAME     := $(PROJECT)-$(ENV)-asg
TG_NAME      := $(PROJECT)-$(ENV)-tg

# Always treat these as commands, never as files
.PHONY: help init fmt validate plan apply outputs verify destroy clean check ci-checks

# --- Help (default) ----------------------------------------------------------
help: ## Show this help message
	@echo "CloudProgramming — make targets"
	@echo "================================"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

# --- Static checks -----------------------------------------------------------
init: ## Run terraform init (downloads providers + modules)
	terraform init

fmt: ## Format all Terraform files in place
	terraform fmt -recursive

validate: init ## Validate the configuration (no AWS calls)
	terraform validate

check: fmt validate ## Format then validate — what CI runs locally

# --- Deploy / destroy --------------------------------------------------------
plan: validate ## Generate a plan and save it to plan.tfplan
	@if [ ! -f terraform.tfvars ]; then \
		echo "ERROR: terraform.tfvars missing. Run: cp terraform.tfvars.example terraform.tfvars"; \
		exit 1; \
	fi
	terraform plan -out=plan.tfplan

apply: plan ## Apply the most recent plan (~15-20 min)
	terraform apply plan.tfplan
	@$(MAKE) outputs

outputs: ## Print public outputs (ALB URL, CloudFront URL)
	@echo ""
	@echo "Application URLs"
	@echo "----------------"
	@terraform output alb_url
	@terraform output cloudfront_url

# Two-step destroy: turn off RDS deletion protection first, then destroy.
destroy: ## Tear the entire stack down (handles RDS deletion protection)
	@echo "Step 1/2: disabling RDS deletion protection..."
	-@aws rds modify-db-instance \
		--db-instance-identifier $(DB_ID) \
		--no-deletion-protection \
		--apply-immediately \
		--region $(REGION) >/dev/null 2>&1 || true
	@echo "Step 2/2: terraform destroy..."
	terraform destroy -auto-approve

# --- Verification (smoke test) ----------------------------------------------
verify: ## Smoke-test the live deployment (cross-AZ load balancing)
	@bash scripts/verify.sh

# --- Housekeeping ------------------------------------------------------------
clean: ## Remove generated state-cache and plan files (keeps tfstate!)
	rm -rf .terraform/ .terraform.lock.hcl plan.tfplan

# --- CI surface --------------------------------------------------------------
ci-checks: ## What GitHub Actions runs on every push (no AWS access)
	terraform fmt -check -recursive
	terraform init -backend=false
	terraform validate
