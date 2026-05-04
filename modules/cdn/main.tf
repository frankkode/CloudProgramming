###############################################################################
# modules/cdn/main.tf
#
# Edge layer:
#   * S3 bucket for static assets (CSS/JS/images, access logs) served through
#     CloudFront via an Origin Access Control — bucket stays private.
#   * AWS WAFv2 WebACL with AWS managed common-rules + known-bad-inputs.
#   * CloudFront distribution with the ALB as dynamic origin and S3 as the
#     /static/* origin.
#   * Optional Route 53 alias record if var.domain_name is set.
###############################################################################

# CloudFront + WAF scope=CLOUDFRONT must live in us-east-1.
# The root module passes its us-east-1 provider in as `aws.useast1`.
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.useast1]
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

# ---- Random suffix for globally-unique S3 name ----------------------------
resource "random_id" "bucket_suffix" {
  byte_length = 3
}

# ---- Private S3 bucket for static assets ---------------------------------
resource "aws_s3_bucket" "static" {
  bucket        = "${var.name_prefix}-static-${random_id.bucket_suffix.hex}"
  force_destroy = true
  tags          = merge(var.tags, { Name = "${var.name_prefix}-static" })
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket                  = aws_s3_bucket.static.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static" {
  bucket = aws_s3_bucket.static.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_versioning" "static" {
  bucket = aws_s3_bucket.static.id
  versioning_configuration { status = "Enabled" }
}

# ---- Origin Access Control (CloudFront → private S3) ---------------------
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "${var.name_prefix}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ---- WAFv2 WebACL (CLOUDFRONT scope) -------------------------------------
resource "aws_wafv2_web_acl" "this" {
  provider    = aws.useast1
  name        = "${var.name_prefix}-waf"
  description = "Common OWASP rules and known-bad-inputs"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "awsCommon"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "awsBadInputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-waf" })
}

# ---- CloudFront distribution ---------------------------------------------
resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.name_prefix} CDN"
  price_class         = var.price_class
  default_root_object = ""
  web_acl_id          = aws_wafv2_web_acl.this.arn

  # Dynamic origin — ALB
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Static origin — S3 via OAC
  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id                = "s3-static"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3.id
  }

  default_cache_behavior {
    target_origin_id       = "alb-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Host", "Origin", "Authorization"]
      cookies { forward = "all" }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 86400
  }

  ordered_cache_behavior {
    path_pattern           = "/static/*"
    target_origin_id       = "s3-static"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-cdn" })
}

# ---- Bucket policy: allow CloudFront OAC to read the bucket --------------
data "aws_iam_policy_document" "s3_oac" {
  statement {
    sid       = "AllowCloudFrontServicePrincipalReadOnly"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.static.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id
  policy = data.aws_iam_policy_document.s3_oac.json
}

# ---- Optional Route 53 alias --------------------------------------------
data "aws_route53_zone" "this" {
  count        = var.domain_name == "" ? 0 : 1
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "alias" {
  count   = var.domain_name == "" ? 0 : 1
  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}
