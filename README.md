# Cloud Programming · Task 1 — Highly Available Web Application on AWS

**Author:** Frank Masabo
**Course:** IU International University of Applied Sciences — Cloud Programming (DLBSEPCP01_E)
**Portfolio part:** Development Phase (Part 2)

This repository contains the first-draft Terraform code that provisions the
architecture designed in the Phase 1 conception document: a three-tier web
application that is highly available, autoscaling and reachable from anywhere
in the world with low latency.

---

## Architecture at a glance

```
                    Global visitors
                          │
                    Route 53 (DNS + health checks)
                          │
          ┌───────────────┴───────────────┐
          │   CloudFront (edge + TLS)     │──── WAF
          │   + S3 (static assets, OAC)   │
          └───────────────┬───────────────┘
                          │
             ┌────────────┴────────────┐
             │   Application Load      │
             │   Balancer (multi-AZ)   │
             └────────┬────────┬───────┘
                      │        │
               ┌──────┴──┐ ┌───┴──────┐
               │ AZ-A    │ │ AZ-B     │
               │ EC2 ASG │ │ EC2 ASG  │   ← target-tracking on CPU + req/target
               └────┬────┘ └────┬─────┘
                    │           │
                    ▼           ▼
                RDS MySQL (Multi-AZ, KMS encrypted)
```

Everything lives in VPC `10.0.0.0/16`, spanning two Availability Zones in
`eu-central-1`. Per-AZ NAT Gateways give the private subnets outbound
internet. CloudWatch collects logs and metrics from every tier.

---

## Repository layout

```
.
├── providers.tf              # Terraform + AWS provider pins
├── variables.tf              # Root input variables
├── main.tf                   # Wires the 5 modules together
├── outputs.tf                # Public outputs (ALB URL, CF domain, …)
├── terraform.tfvars.example  # Copy to terraform.tfvars and fill in secrets
├── .gitignore                # Keeps state + secrets out of git
└── modules/
    ├── network/   # VPC, 6 subnets, IGW, NAT GWs, route tables
    ├── alb/       # ALB, SG, target group, listener
    ├── asg/       # Launch template, ASG, scaling policies, IAM
    ├── rds/       # DB subnet group, SG, MySQL Multi-AZ, KMS
    └── cdn/       # CloudFront, WAF, S3 (OAC), optional Route 53
```

Each module has the standard trio of `main.tf`, `variables.tf`, `outputs.tf`
so it can be reviewed, versioned and reused in isolation.

---

## Requirements

| Tool        | Minimum version | Purpose                          |
|-------------|-----------------|----------------------------------|
| Terraform   | 1.6.0           | Infrastructure as Code engine    |
| AWS CLI     | 2.15            | Credentials + verification       |
| AWS account | —               | With rights to create VPC/ALB/EC2/RDS/CloudFront/WAF |

Authenticate once:

```bash
aws configure              # or `aws sso login --profile <profile>`
export AWS_REGION=eu-central-1
```

---

## Deploy

```bash
# 1. Clone
git clone https://github.com/frankkode/CloudProgramming.git
cd CloudProgramming

# 2. Provide secrets (do NOT commit this file — .gitignore excludes it)
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars      # set db_password (minimum 8 chars)

# 3. Initialise providers + modules
terraform init

# 4. Review what will be created
terraform plan -out plan.tfplan

# 5. Apply
terraform apply plan.tfplan
```

After `apply` completes (CloudFront takes ~10 minutes to roll out globally):

```bash
terraform output alb_url               # http://frank-cloudprog-dev-alb-...
terraform output cloudfront_url        # https://d123...cloudfront.net
```

Open the URL in a browser — the `index.html` served by Apache prints the
Availability Zone of the instance that handled the request, which lets you
verify that traffic is spread across both AZs.

---

## Tear down

```bash
# The RDS instance is deletion-protected by default. Disable it first:
terraform apply -var 'deletion_protection=false'   # (or toggle in tfvars)
terraform destroy
```

> The static-assets S3 bucket is created with `force_destroy = true` so the
> destroy will not fail on remaining objects.

---

## Pushing to GitHub

The exact commands used for the first push:

```bash
git init
git add .
git commit -m "Phase 2: initial Terraform for Task 1"
git remote add origin https://github.com/frankkode/CloudProgramming.git
git branch -M main
git push -u origin main
```

Subsequent iterations follow the standard
`git add … && git commit -m "…" && git push` loop.

---

## Notes on evaluation criteria

* **Problem solving (10 %).** The concept document identified HA, global low
  latency, autoscaling and replicability as the requirements; every module
  here maps to one or more of those goals.
* **Methodology (20 %).** Single-responsibility modules, semantic versioning
  on providers, consistent tagging via `default_tags`, separate tfvars for
  secrets, aliased `useast1` provider for CloudFront-scope WAF.
* **Quality of implementation (40 %).** IMDSv2 enforced, private subnets for
  EC2 and RDS, per-AZ NAT, OAC instead of legacy OAI, KMS + TLS, Multi-AZ
  RDS with backups, AWS-managed WAF rule groups, least-privilege IAM.
* **Creativity (20 %).** Target-tracking on both CPU *and* ALB
  request-per-target, templated user-data that surfaces the serving AZ, OAC
  bucket policy locked to this specific distribution ARN.
* **Formal requirements (10 %).** Conventional repo layout, README with
  deploy/destroy instructions, `.gitignore` that excludes state and secrets.
