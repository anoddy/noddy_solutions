###############################################################################
# Module: lambda
# Runs the FastAPI application on AWS Lambda. Lambda is regional and
# automatically spreads execution environments across multiple Availability
# Zones, and it scales horizontally per request with no capacity planning.
###############################################################################

locals {
  function_name  = "${var.name_prefix}-api"
  log_group_name = "/aws/lambda/${local.function_name}"
}


# Log group created explicitly (rather than implicitly by Lambda) so that the
# retention period is enforced and Terraform removes it on destroy.
resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = var.log_retention_days
}

# Trust policy: only the Lambda service may assume the execution role.
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Execution role for the function.
resource "aws_iam_role" "this" {
  name               = "${local.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Least-privilege permissions: write logs to this function's log group only,
# and send X-Ray trace segments. No other AWS API access is granted.
data "aws_iam_policy_document" "permissions" {
  statement {
    sid       = "WriteOwnLogs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }

  statement {
    sid       = "XRayTracing"
    actions   = ["xray:PutTraceSegments", "xray:PutTelemetryRecords"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "${local.function_name}-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.permissions.json
}

# The Lambda function itself. `publish = true` creates an immutable version on
# every code change, which the "live" alias below points to.
resource "aws_lambda_function" "this" {
  function_name    = local.function_name
  description      = "FastAPI landing page served via Mangum"
  role             = aws_iam_role.this.arn
  filename         = var.package_path
  source_code_hash = filebase64sha256(var.package_path)
  handler          = var.handler
  runtime          = var.runtime
  architectures    = [var.architecture]
  memory_size      = var.memory_size
  timeout          = var.timeout
  publish          = true

  # Caps concurrency to protect downstream systems and the monthly bill
  # (-1 leaves the function in the shared, unreserved account pool).
  reserved_concurrent_executions = var.reserved_concurrent_executions

  environment {
    variables = var.environment_variables
  }

  # Active tracing gives end-to-end latency visibility in AWS X-Ray.
  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy.this,
  ]
}

# Stable alias that API Gateway invokes. Enables safe roll-forward/rollback
# and is the only target that supports provisioned concurrency.
resource "aws_lambda_alias" "live" {
  name             = "live"
  description      = "Production traffic alias"
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version
}

# Optional warm pool that removes cold-start latency for latency-critical
# workloads. Disabled by default to preserve pure pay-per-use pricing.
resource "aws_lambda_provisioned_concurrency_config" "this" {
  count = var.provisioned_concurrency > 0 ? 1 : 0

  function_name                     = aws_lambda_function.this.function_name
  qualifier                         = aws_lambda_alias.live.name
  provisioned_concurrent_executions = var.provisioned_concurrency
}
