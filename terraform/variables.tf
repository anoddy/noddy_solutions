###############################################################################
# Input variables — root module
###############################################################################

# --- General -----------------------------------------------------------------
variable "project_name" {
  description = "Short project identifier used as a name prefix for all resources."
  type        = string
  default     = "nimbus-landing"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.project_name))
    error_message = "project_name must be 3-30 characters of lowercase letters, digits or hyphens."
  }
}

variable "environment" {
  description = "Deployment stage (e.g. dev, staging, prod)."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "Primary AWS region for API Gateway and Lambda."
  type        = string
  default     = "eu-central-1"
}

variable "extra_tags" {
  description = "Additional tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "company_name" {
  description = "Company name rendered on the landing page."
  type        = string
  default     = "Noddy Solutions"
}

# --- Lambda ------------------------------------------------------------------
variable "lambda_package_path" {
  description = "Path to the zip built by scripts/build_lambda.sh."
  type        = string
  default     = "../build/lambda.zip"
}

variable "lambda_runtime" {
  description = "Lambda Python runtime."
  type        = string
  default     = "python3.12"
}

variable "lambda_architecture" {
  description = "Instruction set: arm64 (Graviton, ~20% cheaper) or x86_64."
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.lambda_architecture)
    error_message = "lambda_architecture must be arm64 or x86_64."
  }
}

variable "lambda_memory_size" {
  description = "Memory in MB (CPU scales proportionally)."
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Maximum execution time per request, in seconds."
  type        = number
  default     = 10
}

variable "lambda_reserved_concurrency" {
  description = "Upper bound on concurrent executions (-1 = no reservation, use account pool)."
  type        = number
  default     = -1
}

variable "lambda_provisioned_concurrency" {
  description = "Pre-initialised environments to eliminate cold starts (0 = disabled, pay-per-use only)."
  type        = number
  default     = 0
}

# --- API Gateway -------------------------------------------------------------
variable "api_throttling_burst_limit" {
  description = "Maximum request burst accepted by API Gateway."
  type        = number
  default     = 2000
}

variable "api_throttling_rate_limit" {
  description = "Steady-state requests per second accepted by API Gateway."
  type        = number
  default     = 1000
}

# --- CloudFront / WAF --------------------------------------------------------
variable "cloudfront_price_class" {
  description = "PriceClass_All (global), PriceClass_200 or PriceClass_100 (NA/EU only)."
  type        = string
  default     = "PriceClass_All"
}

variable "enable_waf" {
  description = "Attach an AWS WAF web ACL (managed rules + rate limiting) to CloudFront."
  type        = bool
  default     = true
}

variable "waf_rate_limit_per_5min" {
  description = "Requests allowed per client IP in a rolling 5-minute window before blocking."
  type        = number
  default     = 2000
}

# --- Custom domain (optional) ------------------------------------------------
variable "domain_name" {
  description = "Apex/primary domain (e.g. example.com). Leave empty to use the *.cloudfront.net domain."
  type        = string
  default     = ""
}

variable "subject_alternative_names" {
  description = "Additional hostnames served by the distribution (e.g. [\"www.example.com\"])."
  type        = list(string)
  default     = []
}

variable "hosted_zone_id" {
  description = "Route 53 public hosted zone ID for domain_name. Leave empty to skip DNS."
  type        = string
  default     = ""
}

# --- Observability -----------------------------------------------------------
variable "log_retention_days" {
  description = "CloudWatch Logs retention period."
  type        = number
  default     = 14
}
