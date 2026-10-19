# Módulo `lambda-function`

Empaqueta un directorio en un `.zip` (con el provider `archive`) y crea la
`aws_lambda_function` junto con su log group. Opcionalmente la mete en la VPC.

## Uso

```hcl
module "lambdas" {
  source   = "../modules/lambda-function"
  for_each = local.lambdas

  name        = "${local.name_prefix}-${each.key}"
  source_dir  = "${path.root}/../../lambdas/${each.key}"
  handler     = "handler.handler"
  role_arn    = data.aws_iam_role.lab_role.arn
  environment = each.value.environment
  vpc_config  = each.value.in_vpc ? local.lambda_vpc_config : null
  tags        = local.common_tags
}
```
