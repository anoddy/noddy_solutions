output "api_endpoint" {
  description = "Base HTTPS URL of the HTTP API."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "api_id" {
  description = "HTTP API identifier."
  value       = aws_apigatewayv2_api.this.id
}
