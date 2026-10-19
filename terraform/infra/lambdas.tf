## Las 5 tareas cortas y ocasionales de AccesoSeguro. Una función por tarea,
## todas en Python con LabRole, armadas con una sola llamada a for_each.

module "lambdas" {
  source   = "../modules/lambda-function"
  for_each = local.lambdas

  name        = "${local.name_prefix}-${each.key}"
  source_dir  = "${path.root}/../../lambdas/${each.key}"
  handler     = "handler.handler"
  role_arn    = data.aws_iam_role.lab_role.arn
  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout
  environment = each.value.environment
  vpc_config  = each.value.in_vpc ? local.lambda_vpc_config : null
  tags        = local.common_tags
}
