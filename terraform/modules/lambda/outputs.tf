output "function_name" {
  description = "Lambda function name."
  value       = aws_lambda_function.this.function_name
}

output "alias_name" {
  description = "Name of the traffic alias."
  value       = aws_lambda_alias.live.name
}

output "alias_invoke_arn" {
  description = "Invoke ARN of the live alias (used by API Gateway)."
  value       = aws_lambda_alias.live.invoke_arn
}

output "log_group_name" {
  description = "CloudWatch log group name."
  value       = aws_cloudwatch_log_group.this.name
}
