###############################################################################
# variables.tf  —  Root-level input variables
###############################################################################

variable "project" {
  description = "Short project identifier used in resource names and tags."
  type        = string
  default     = "frank-cloudprog"
}

variable "environment" {
  description = "Deployment environment (dev / staging / prod)."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region to deploy all resources into."
  type        = string
  default     = "eu-central-1"
}

variable "availability_zones" {
  description = "Exactly two AZs — one per public/private/data subnet pair."
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Deploy into exactly two Availability Zones for Multi-AZ HA."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the two public (ALB / NAT) subnets."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "CIDR blocks for the two private application (EC2) subnets."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_data_subnet_cidrs" {
  description = "CIDR blocks for the two private data (RDS) subnets."
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

variable "instance_type" {
  description = "EC2 instance type for the web tier."
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Minimum number of EC2 instances in the Auto Scaling Group."
  type        = number
  default     = 2
}

variable "asg_max_size" {
  description = "Maximum number of EC2 instances in the Auto Scaling Group."
  type        = number
  default     = 6
}

variable "asg_desired_capacity" {
  description = "Desired number of EC2 instances at provisioning time."
  type        = number
  default     = 2
}

variable "db_instance_class" {
  description = "Instance class for the RDS MySQL database."
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GiB."
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Initial database name created in RDS."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Master username for the RDS instance."
  type        = string
  default     = "appadmin"
  sensitive   = true
}

variable "db_password" {
  description = "Master password for the RDS instance (use a tfvars file or secrets manager)."
  type        = string
  sensitive   = true
}

variable "enable_cloudfront" {
  description = "Whether to create the CloudFront + WAF edge layer."
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Optional public domain (leave empty to skip Route 53 config)."
  type        = string
  default     = ""
}
