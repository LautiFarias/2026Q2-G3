## Documentos (privado, presigned URLs) y auditoría (copia de respaldo +
## reportes CSV): dos buckets con el mismo módulo externo, distinto ciclo
## de vida cada uno porque cada uno tiene un uso distinto.

locals {
  buckets = {
    documentos = {
      lifecycle_rules = [{
        id = "documentos-ciclo-vida"
        transitions = [
          { days = 30, storage_class = "STANDARD_IA" },
          { days = 180, storage_class = "GLACIER_IR" },
        ]
        expiration_days            = var.document_retention_days
        noncurrent_expiration_days = 30
        abort_multipart_days       = 7
      }]
    }

    auditoria = {
      lifecycle_rules = [{
        id                         = "auditoria-ciclo-vida"
        transitions                = [{ days = 30, storage_class = "GLACIER_IR" }]
        noncurrent_expiration_days = 30
        abort_multipart_days       = 7
      }]
    }
  }
}

module "buckets" {
  source = "../modules/s3-bucket"

  for_each = local.buckets

  bucket_name     = "${local.name_prefix}-${each.key}"
  kms_key_arn     = aws_kms_key.main.arn
  lifecycle_rules = each.value.lifecycle_rules

  # Solo el bucket de documentos recibe subidas directas desde el navegador.
  cors_rules = each.key == "documentos" ? [{
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = [local.sitio_origin]
  }] : []

  tags = local.common_tags
}
