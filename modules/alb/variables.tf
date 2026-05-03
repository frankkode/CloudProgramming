variable "name_prefix" {
  description = "Prefix applied to every resource name and Name tag."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC the ALB lives in."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (one per AZ) the ALB attaches to."
  type        = list(string)
}

variable "health_check_path" {
  description = "HTTP path the ALB probes on the targets."
  type        = string
  default     = "/"
}

variable "tags" {
  description = "Common tags merged onto every resource."
  type        = map(string)
  default     = {}
}
