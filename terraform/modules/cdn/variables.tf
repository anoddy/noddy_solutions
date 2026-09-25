variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "api_endpoint" {
  description = "HTTPS endpoint of the API Gateway origin."
  type        = string
}

variable "origin_verify_secret" {
  description = "Secret header value sent to the origin."
  type        = string
  sensitive   = true
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
}

variable "aliases" {
  description = "Custom hostnames (CNAMEs) for the distribution."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN in us-east-1 (null = default certificate)."
  type        = string
  default     = null
}

variable "enable_waf" {
  description = "Whether to create and attach a WAF web ACL."
  type        = bool
}

variable "waf_rate_limit" {
  description = "Requests per IP per 5 minutes."
  type        = number
}
