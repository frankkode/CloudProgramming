output "asg_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.web.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group."
  value       = aws_autoscaling_group.web.arn
}

output "instance_security_group_id" {
  description = "ID of the security group attached to the instances."
  value       = aws_security_group.instance.id
}

output "launch_template_id" {
  description = "ID of the launch template driving the ASG."
  value       = aws_launch_template.web.id
}

output "instance_role_name" {
  description = "Name of the IAM role attached to the EC2 instances."
  value       = aws_iam_role.instance.name
}
