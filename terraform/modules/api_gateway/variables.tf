variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda alias."
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name (for the invoke permission)."
  type        = string
}

variable "lambda_alias_name" {
  description = "Lambda alias name (for the invoke permission)."
  type        = string
}

variable "throttling_burst" {
  description = "Burst limit."
  type        = number
}

variable "throttling_rate" {
  description = "Steady-state rate limit (req/s)."
  type        = number
}

variable "log_retention_days" {
  description = "Access log retention."
  type        = number
}
