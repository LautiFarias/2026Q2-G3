## Empaqueta el código de una Lambda y la crea con su log group.
## Una llamada a este módulo con for_each (en lambdas.tf) arma las 5 funciones.

data "archive_file" "this" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.root}/.build/${var.name}.zip"
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_lambda_function" "this" {
  function_name = var.name
  role          = var.role_arn
  handler       = var.handler
  runtime       = var.runtime

  filename         = data.archive_file.this.output_path
  source_code_hash = data.archive_file.this.output_base64sha256

  memory_size = var.memory_size
  timeout     = var.timeout

  environment {
    variables = var.environment
  }

  # Las Lambdas que necesitan RDS van en la VPC; las que no, quedan afuera
  # para no sumar latencia de ENI sin necesidad.
  dynamic "vpc_config" {
    for_each = var.vpc_config == null ? [] : [var.vpc_config]
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]

  tags = var.tags
}
