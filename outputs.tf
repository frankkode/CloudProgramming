###############################################################################
# outputs.tf  —  Root-level outputs (what to expose to the user after apply)
###############################################################################

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "alb_dns_name" {
  description = "DNS name of the public Application Load Balancer."
  value       = module.alb.alb_dns_name
}

output "alb_url" {
  description = "Convenience URL to hit the ALB directly."
  value       = "http://${module.alb.alb_dns_name}"
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain (null if edge layer disabled)."
  value       = try(module.cdn[0].cloudfront_domain_name, null)
}

output "cloudfront_url" {
  description = "HTTPS URL in front of CloudFront (null if edge layer disabled)."
  value       = try("https://${module.cdn[0].cloudfront_domain_name}", null)
}

output "rds_endpoint" {
  description = "Connection endpoint for the RDS MySQL primary."
  value       = module.rds.db_endpoint
  sensitive   = true
}

output "asg_name" {
  description = "Name of the Auto Scaling Group hosting the web tier."
  value       = module.asg.asg_name
}
