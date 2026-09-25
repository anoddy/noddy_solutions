variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID."
  type        = string
}

variable "record_names" {
  description = "Hostnames to point at CloudFront."
  type        = list(string)
}

variable "cloudfront_domain_name" {
  description = "CloudFront distribution domain."
  type        = string
}

variable "cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID for alias records."
  type        = string
}
