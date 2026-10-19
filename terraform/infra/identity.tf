## Cognito: el padrón de usuarios. Login directo del navegador con el SDK
## (sin Hosted UI ni API Gateway: así lo definió la devolución de la
## cátedra del 16/10, ver PDF de arquitectura). La API en ECS verifica el
## token en cada pedido y lee el grupo / empresa / sede.

resource "aws_cognito_user_pool" "main" {
  name = "${local.name_prefix}-usuarios"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  # Atributo de empresa: lo asigna un administrador, el transportista no lo
  # puede modificar (mutable=true a nivel schema, pero el app client no pide
  # permiso de escritura sobre este atributo).
  schema {
    name                = "empresa_id"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 64
    }
  }

  schema {
    name                = "sede_id"
    attribute_data_type = "String"
    mutable             = true
    string_attribute_constraints {
      min_length = 0
      max_length = 64
    }
  }

  # Cognito no permite modificar el schema de un pool existente (lo recrearía
  # y se perderían los usuarios), así que Terraform no debe intentarlo.
  lifecycle {
    ignore_changes = [schema]
  }

  tags = local.common_tags
}

locals {
  cognito_groups = toset(["responsables_sede", "porteria"])
}

resource "aws_cognito_user_group" "grupos" {
  for_each = local.cognito_groups

  name         = each.key
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Grupo ${each.key} de AccesoSeguro"
}

# App client público (sin secret): lo usa el SDK en el navegador.
resource "aws_cognito_user_pool_client" "app" {
  name         = "${local.name_prefix}-app-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  prevent_user_existence_errors = "ENABLED"
  access_token_validity         = 1
  id_token_validity             = 1
  refresh_token_validity        = 30
  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  read_attributes  = ["email", "custom:empresa_id", "custom:sede_id"]
  write_attributes = ["email"]
}
