###############################################################################
# Module: cdn
# Amazon CloudFront terminates TLS at 400+ edge locations worldwide, caches
# cacheable responses close to visitors and carries dynamic requests to the
# origin over the optimised AWS backbone. An optional AWS WAF web ACL filters
# malicious traffic before it reaches the origin.
###############################################################################

terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

locals {
  origin_id     = "api-gateway-origin"
  origin_domain = replace(var.api_endpoint, "https://", "")
}

# --- AWS-managed policies (looked up by name) --------------------------------

# Forward all viewer headers/cookies/query strings EXCEPT Host, which must be
# the API Gateway hostname for the request to be routed correctly.
data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

# Long-lived edge caching for immutable static assets.
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# No caching at all (health checks).
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

# Adds HSTS, X-Content-Type-Options, X-Frame-Options, Referrer-Policy, etc.
data "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "Managed-SecurityHeadersPolicy"
}

# --- Custom cache policy for dynamic HTML -------------------------------------
# Honours the origin's Cache-Control header (FastAPI sends max-age=300 for the
# landing page) and never caches longer than one hour. Compression is enabled
# so CloudFront serves Brotli/Gzip to supporting browsers.
resource "aws_cloudfront_cache_policy" "dynamic" {
  name        = "${var.name_prefix}-dynamic-html"
  comment     = "Respect origin Cache-Control for dynamic pages"
  min_ttl     = 0
  default_ttl = 0
  max_ttl     = 3600

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_brotli = true
    enable_accept_encoding_gzip   = true

    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

# --- AWS WAF (must be created in us-east-1 for CloudFront scope) -------------
resource "aws_wafv2_web_acl" "this" {
  count    = var.enable_waf ? 1 : 0
  provider = aws.us_east_1

  name        = "${var.name_prefix}-edge-waf"
  description = "Edge protection for the landing page"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  # Rule 1: per-IP rate limiting mitigates HTTP floods and scraping.
  rule {
    name     = "rate-limit-per-ip"
    priority = 0

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "rate-limit-per-ip"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: AWS-maintained reputation list of malicious IPs/bots.
  rule {
    name     = "aws-ip-reputation"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesAmazonIpReputationList"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-ip-reputation"
      sampled_requests_enabled   = true
    }
  }

  # Rule 3: OWASP Top-10 style protections (XSS, LFI, bad bots, ...).
  rule {
    name     = "aws-common-rules"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-common-rules"
      sampled_requests_enabled   = true
    }
  }

  # Rule 4: blocks request patterns known to exploit vulnerabilities (e.g. Log4j).
  rule {
    name     = "aws-known-bad-inputs"
    priority = 3

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "aws-known-bad-inputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-edge-waf"
    sampled_requests_enabled   = true
  }
}

# --- CloudFront distribution --------------------------------------------------
resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2and3"
  comment         = "${var.name_prefix} landing page"
  price_class     = var.price_class
  aliases         = var.aliases
  web_acl_id      = var.enable_waf ? aws_wafv2_web_acl.this[0].arn : null

  # Single origin: the API Gateway HTTP API. HTTPS-only, TLS 1.2, with the
  # shared secret header that proves the request came through CloudFront.
  origin {
    origin_id   = local.origin_id
    domain_name = local.origin_domain

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
      origin_read_timeout    = 30
    }

    custom_header {
      name  = "x-origin-verify"
      value = var.origin_verify_secret
    }
  }

  # Default behaviour: dynamic HTML rendered by FastAPI.
  default_cache_behavior {
    target_origin_id           = local.origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = aws_cloudfront_cache_policy.dynamic.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
  }

  # Static assets (CSS, images): cached aggressively at the edge.
  ordered_cache_behavior {
    path_pattern               = "/static/*"
    target_origin_id           = local.origin_id
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.security_headers.id
  }

  # Health endpoint: never cached, always reflects the origin's real state.
  ordered_cache_behavior {
    path_pattern             = "/health"
    target_origin_id         = local.origin_id
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["GET", "HEAD"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
  }

  # Serve error responses briefly from cache to shield the origin during
  # incidents (negative caching).
  custom_error_response {
    error_code            = 502
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 503
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Custom certificate when a domain is configured; otherwise the default
  # *.cloudfront.net certificate.
  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == null
    acm_certificate_arn            = var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn == null ? null : "sni-only"
    minimum_protocol_version       = var.acm_certificate_arn == null ? "TLSv1" : "TLSv1.2_2021"
  }
}
