variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "package_path" {
  description = "Path to the deployment zip."
  type        = string
}

variable "handler" {
  description = "Python handler (module.attribute)."
  type        = string
}

variable "runtime" {
  description = "Lambda runtime identifier."
  type        = string
}

variable "architecture" {
  description = "arm64 or x86_64."
  type        = string
}

variable "memory_size" {
  description = "Memory in MB."
  type        = number
}

variable "timeout" {
  description = "Timeout in seconds."
  type        = number
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrency (-1 = unreserved)."
  type        = number
}

variable "provisioned_concurrency" {
  description = "Provisioned concurrency on the live alias (0 = disabled)."
  type        = number
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention."
  type        = number
}

variable "environment_variables" {
  description = "Environment variables passed to the function."
  type        = map(string)
  default     = {}
  sensitive   = true
}
