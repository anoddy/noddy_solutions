###############################################################################
# Root module — Serverless FastAPI landing page
#
#   Visitor ──► Route 53 ──► CloudFront (+WAF) ──► API Gateway HTTP API ──► Lambda (FastAPI/Mangum)
#
# Each layer is a separate child module under ./modules so it can be reused,
# tested and reasoned about independently.
###############################################################################

# Primary provider: the region that hosts API Gateway and Lambda.
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Secondary provider pinned to us-east-1. CloudFront only accepts ACM
# certificates and WAF web ACLs that live in us-east-1.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}

locals {
  name_prefix       = "${var.project_name}-${var.environment}"
  use_custom_domain = var.domain_name != "" && var.hosted_zone_id != ""

  common_tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.extra_tags,
  )
}

# Shared secret that CloudFront adds to every origin request. The Lambda
# application rejects requests lacking it, so the raw API Gateway URL cannot
# be used to bypass CloudFront/WAF.
resource "random_password" "origin_verify" {
  length  = 40
  special = false
}

# ---------------------------------------------------------------------------
# Compute layer: Lambda function running FastAPI via Mangum
# ---------------------------------------------------------------------------
module "lambda" {
  source = "./modules/lambda"

  name_prefix                    = local.name_prefix
  package_path                   = var.lambda_package_path
  handler                        = "app.main.handler"
  runtime                        = var.lambda_runtime
  architecture                   = var.lambda_architecture
  memory_size                    = var.lambda_memory_size
  timeout                        = var.lambda_timeout
  reserved_concurrent_executions = var.lambda_reserved_concurrency
  provisioned_concurrency        = var.lambda_provisioned_concurrency
  log_retention_days             = var.log_retention_days

  environment_variables = {
    COMPANY_NAME         = var.company_name
    ORIGIN_VERIFY_SECRET = random_password.origin_verify.result
  }
}

# ---------------------------------------------------------------------------
# Routing layer: API Gateway HTTP API proxying everything to Lambda
# ---------------------------------------------------------------------------
module "api_gateway" {
  source = "./modules/api_gateway"

  name_prefix          = local.name_prefix
  lambda_invoke_arn    = module.lambda.alias_invoke_arn
  lambda_function_name = module.lambda.function_name
  lambda_alias_name    = module.lambda.alias_name
  throttling_burst     = var.api_throttling_burst_limit
  throttling_rate      = var.api_throttling_rate_limit
  log_retention_days   = var.log_retention_days
}

# ---------------------------------------------------------------------------
# TLS certificate (only when a custom domain is configured)
# ---------------------------------------------------------------------------
module "certificate" {
  source = "./modules/certificate"
  count  = local.use_custom_domain ? 1 : 0

  providers = {
    aws = aws.us_east_1
  }

  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  hosted_zone_id            = var.hosted_zone_id
}

# ---------------------------------------------------------------------------
# Edge layer: CloudFront distribution (+ optional AWS WAF)
# ---------------------------------------------------------------------------
module "cdn" {
  source = "./modules/cdn"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  name_prefix          = local.name_prefix
  api_endpoint         = module.api_gateway.api_endpoint
  origin_verify_secret = random_password.origin_verify.result
  price_class          = var.cloudfront_price_class
  aliases              = local.use_custom_domain ? concat([var.domain_name], var.subject_alternative_names) : []
  acm_certificate_arn  = local.use_custom_domain ? module.certificate[0].certificate_arn : null
  enable_waf           = var.enable_waf
  waf_rate_limit       = var.waf_rate_limit_per_5min
}

# ---------------------------------------------------------------------------
# DNS layer: Route 53 alias records pointing the domain at CloudFront
# ---------------------------------------------------------------------------
module "dns" {
  source = "./modules/dns"
  count  = local.use_custom_domain ? 1 : 0

  hosted_zone_id            = var.hosted_zone_id
  record_names              = concat([var.domain_name], var.subject_alternative_names)
  cloudfront_domain_name    = module.cdn.distribution_domain_name
  cloudfront_hosted_zone_id = module.cdn.distribution_hosted_zone_id
}
