###############################################################################
# Outputs — root module
###############################################################################

output "website_url" {
  description = "Public URL of the landing page."
  value       = local.use_custom_domain ? "https://${var.domain_name}" : "https://${module.cdn.distribution_domain_name}"
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain."
  value       = module.cdn.distribution_domain_name
}

output "cloudfront_distribution_id" {
  description = "Distribution ID (use for cache invalidations)."
  value       = module.cdn.distribution_id
}

output "api_endpoint" {
  description = "Raw API Gateway endpoint (direct access is rejected by the origin-verify check)."
  value       = module.api_gateway.api_endpoint
}

output "lambda_function_name" {
  description = "Name of the Lambda function."
  value       = module.lambda.function_name
}

output "lambda_log_group" {
  description = "CloudWatch log group for application logs."
  value       = module.lambda.log_group_name
}
