output "vpc_id" {
  description = "ID of the created VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the two public (ALB / NAT) subnets."
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs of the two private application (EC2) subnets."
  value       = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  description = "IDs of the two private data (RDS) subnets."
  value       = aws_subnet.private_data[*].id
}

output "nat_gateway_ids" {
  description = "IDs of the per-AZ NAT Gateways."
  value       = aws_nat_gateway.this[*].id
}
