## Primer Terraform: crea el bucket S3 donde va a vivir el state del segundo
## Terraform (infra/) y le genera su backend.hcl. Este proyecto guarda SU
## PROPIO state en local (bootstrap/terraform.tfstate) porque todavía no
## existe otro lugar donde guardarlo.

data "aws_caller_identity" "current" {}

locals {
  # coalesce(): usa el nombre pasado por variable: si vino vacío, genera uno
  # único a nivel global con el account id.
  bucket_name = coalesce(
    length(var.state_bucket_name) > 0 ? var.state_bucket_name : null,
    "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
  )

  tags = merge(var.tags, {
    Proyecto       = var.project
    Gestionado-por = "terraform-bootstrap"
  })
}

# Mismo módulo que usa infra/ (bucket vía CloudFormation, ver su README).
# No se vacía al destruir: es el bucket que guarda el state de toda la infra.
module "state_bucket" {
  source = "../modules/s3-bucket"

  bucket_name      = local.bucket_name
  empty_on_destroy = false
  tags             = merge(local.tags, { Name = local.bucket_name })
}

# Método clásico de lock (queda como opción si alguien corre Terraform < 1.10).
resource "aws_dynamodb_table" "tf_locks" {
  count        = var.create_dynamodb_lock_table ? 1 : 0
  name         = "${local.bucket_name}-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.tags
}

# Le arma a infra/ su backend.hcl, con el bucket que acabamos de crear.
resource "local_file" "backend_hcl" {
  filename = "${path.module}/../infra/backend.hcl"
  content = templatefile("${path.module}/templates/backend.hcl.tftpl", {
    bucket = module.state_bucket.bucket_id
    key    = "${var.project}/${var.environment}/terraform.tfstate"
    region = var.region
  })
}
