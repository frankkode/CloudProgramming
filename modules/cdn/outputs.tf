output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.this.id
}

output "waf_web_acl_arn" {
  description = "ARN of the WAFv2 WebACL."
  value       = aws_wafv2_web_acl.this.arn
}

output "static_bucket_name" {
  description = "Name of the static-assets S3 bucket."
  value       = aws_s3_bucket.static.bucket
}
