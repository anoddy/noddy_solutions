###############################################################################
# Module: dns
# Route 53 alias records mapping the custom domain to CloudFront. Route 53 is
# a globally anycast DNS service with a 100% availability SLA; alias records
# to CloudFront are free of query charges and resolve at the zone apex.
###############################################################################

# IPv4 alias record for each hostname.
resource "aws_route53_record" "ipv4" {
  for_each = toset(var.record_names)

  zone_id = var.hosted_zone_id
  name    = each.value
  type    = "A"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# IPv6 alias record for each hostname (CloudFront is dual-stack).
resource "aws_route53_record" "ipv6" {
  for_each = toset(var.record_names)

  zone_id = var.hosted_zone_id
  name    = each.value
  type    = "AAAA"

  alias {
    name                   = var.cloudfront_domain_name
    zone_id                = var.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}
