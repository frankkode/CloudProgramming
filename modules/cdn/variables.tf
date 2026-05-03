variable "name_prefix" {
  description = "Prefix applied to every resource name and Name tag."
  type        = string
}

variable "alb_dns_name" {
  description = "DNS name of the ALB used as CloudFront origin."
  type        = string
}

variable "domain_name" {
  description = "Optional public domain (if empty, no Route 53 record is created)."
  type        = string
  default     = ""
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

variable "tags" {
  description = "Common tags merged onto every resource."
  type        = map(string)
  default     = {}
}
