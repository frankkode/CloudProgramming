###############################################################################
# main.tf  —  Root composition
#
# Wires the five modules together:
#     network  →  alb  →  asg  →  rds  →  cdn
#
# Each module has a single, narrow responsibility and exposes only the IDs
# the next layer needs. The root stays readable and linkable from slides.
###############################################################################

locals {
  name_prefix = "${var.project}-${var.environment}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
  }
}

# 1. Networking: VPC, subnets, IGW, NAT GWs, route tables -----------------
module "network" {
  source = "./modules/network"

  name_prefix               = local.name_prefix
  vpc_cidr                  = var.vpc_cidr
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs
  tags                      = local.common_tags
}

# 2. Application Load Balancer + SGs + target group ----------------------
module "alb" {
  source = "./modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
  tags              = local.common_tags
}

# 3. Auto Scaling Group (compute tier) -----------------------------------
module "asg" {
  source = "./modules/asg"

  name_prefix            = local.name_prefix
  vpc_id                 = module.network.vpc_id
  private_app_subnet_ids = module.network.private_app_subnet_ids
  alb_security_group_id  = module.alb.alb_security_group_id
  target_group_arn       = module.alb.target_group_arn
  instance_type          = var.instance_type
  min_size               = var.asg_min_size
  max_size               = var.asg_max_size
  desired_capacity       = var.asg_desired_capacity
  tags                   = local.common_tags
}

# 4. RDS MySQL Multi-AZ --------------------------------------------------
module "rds" {
  source = "./modules/rds"

  name_prefix             = local.name_prefix
  vpc_id                  = module.network.vpc_id
  private_data_subnet_ids = module.network.private_data_subnet_ids
  app_security_group_id   = module.asg.instance_security_group_id
  instance_class          = var.db_instance_class
  allocated_storage       = var.db_allocated_storage
  db_name                 = var.db_name
  db_username             = var.db_username
  db_password             = var.db_password
  tags                    = local.common_tags
}

# 5. Edge layer: CloudFront + WAF + S3 ----------------------------------
module "cdn" {
  source = "./modules/cdn"
  count  = var.enable_cloudfront ? 1 : 0

  providers = {
    aws         = aws
    aws.useast1 = aws.useast1
  }

  name_prefix  = local.name_prefix
  alb_dns_name = module.alb.alb_dns_name
  domain_name  = var.domain_name
  tags         = local.common_tags
}
