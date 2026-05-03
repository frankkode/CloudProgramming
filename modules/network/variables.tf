variable "name_prefix" {
  description = "Prefix applied to every resource name and Name tag."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC (e.g. 10.0.0.0/16)."
  type        = string
}

variable "availability_zones" {
  description = "Two AZs across which all subnets are mirrored."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "Two CIDRs for the public subnets (ALB + NAT GW)."
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "Two CIDRs for the private application (EC2) subnets."
  type        = list(string)
}

variable "private_data_subnet_cidrs" {
  description = "Two CIDRs for the private data (RDS) subnets."
  type        = list(string)
}

variable "tags" {
  description = "Common tags merged onto every resource."
  type        = map(string)
  default     = {}
}
