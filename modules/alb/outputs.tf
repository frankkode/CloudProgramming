output "alb_arn" {
  description = "ARN of the Application Load Balancer."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB (use as CloudFront origin)."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Route 53 hosted zone ID of the ALB (for alias records)."
  value       = aws_lb.this.zone_id
}

output "alb_security_group_id" {
  description = "ID of the security group protecting the ALB."
  value       = aws_security_group.alb.id
}

output "target_group_arn" {
  description = "ARN of the target group the ASG registers instances with."
  value       = aws_lb_target_group.web.arn
}
