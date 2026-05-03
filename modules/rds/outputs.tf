output "db_endpoint" {
  description = "Endpoint (host:port) of the RDS primary."
  value       = aws_db_instance.this.endpoint
  sensitive   = true
}

output "db_identifier" {
  description = "Identifier of the RDS instance."
  value       = aws_db_instance.this.identifier
}

output "db_security_group_id" {
  description = "ID of the DB security group."
  value       = aws_security_group.db.id
}

output "db_kms_key_arn" {
  description = "ARN of the KMS CMK encrypting RDS."
  value       = aws_kms_key.rds.arn
}
