###############################################################################
# Module: api_gateway
# HTTP API (API Gateway v2): the managed, multi-AZ public entry point that
# forwards every request to Lambda. Chosen over REST API for ~70% lower cost
# and lower latency; its feature set is sufficient for a proxy integration.
###############################################################################

# Access logs for auditing and troubleshooting.
resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${var.name_prefix}-http-api"
  retention_in_days = var.log_retention_days
}

# The HTTP API itself.
resource "aws_apigatewayv2_api" "this" {
  name          = "${var.name_prefix}-http-api"
  description   = "Public entry point for the FastAPI landing page"
  protocol_type = "HTTP"
}

# Lambda proxy integration using payload format 2.0 (understood by Mangum).
resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = var.lambda_invoke_arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000
}

# Catch-all route: FastAPI performs the actual path routing.
resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Auto-deployed default stage with throttling (protects Lambda from floods)
# and structured JSON access logging.
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = var.throttling_burst
    throttling_rate_limit  = var.throttling_rate
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      path           = "$context.path"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      latencyMs      = "$context.responseLatency"
      integrationErr = "$context.integrationErrorMessage"
    })
  }
}

# Resource-based policy on the Lambda alias: allows only this API to invoke it.
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowInvokeFromHttpApi"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  qualifier     = var.lambda_alias_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
