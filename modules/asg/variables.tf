variable "name_prefix" {
  description = "Prefix applied to every resource name and Name tag."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC."
  type        = string
}

variable "private_app_subnet_ids" {
  description = "Private application subnet IDs (one per AZ)."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB (allowed as ingress source)."
  type        = string
}

variable "target_group_arn" {
  description = "ARN of the ALB target group to register with."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the web tier."
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum size of the Auto Scaling Group."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum size of the Auto Scaling Group."
  type        = number
  default     = 6
}

variable "desired_capacity" {
  description = "Desired number of instances on initial provisioning."
  type        = number
  default     = 2
}

variable "cpu_target" {
  description = "Target average CPU utilisation percentage for scaling."
  type        = number
  default     = 50
}

variable "request_count_target" {
  description = "Target ALB requests-per-instance for scaling."
  type        = number
  default     = 1000
}

variable "tags" {
  description = "Common tags merged onto every resource."
  type        = map(string)
  default     = {}
}

variable "alb_arn_suffix" {
  description = "ARN suffix of the ALB."
  type        = string
}

variable "target_group_arn_suffix" {
  description = "ARN suffix of the target group."
  type        = string
}
