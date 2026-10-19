## Bucket S3 con su configuración (versionado, cifrado, acceso público,
## ciclo de vida, CORS, sitio web y policy).
##
## Por qué el bucket se crea con CloudFormation y no con aws_s3_bucket: en el
## Learner Lab una política de la organización (SCP) deniega
## s3:GetBucketObjectLockConfiguration, y el recurso aws_s3_bucket del
## provider siempre lee esa configuración y falla con AccessDenied. El stack
## de CloudFormation crea el bucket y el resto de la configuración sigue
## siendo recursos normales de Terraform (aws_s3_bucket_*).

locals {
  stack_name = "s3-${replace(var.bucket_name, ".", "-")}"

  policy_statements = concat(
    var.deny_insecure_transport ? [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [aws_cloudformation_stack.bucket.outputs["Arn"], "${aws_cloudformation_stack.bucket.outputs["Arn"]}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }] : [],
    var.public_read ? [{
      Sid       = "LecturaPublicaSoloGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_cloudformation_stack.bucket.outputs["Arn"]}/*"
    }] : [],
    var.extra_policy_statements
  )
}

resource "aws_cloudformation_stack" "bucket" {
  name = local.stack_name

  template_body = jsonencode({
    AWSTemplateFormatVersion = "2010-09-09"
    Resources = {
      Bucket = {
        Type       = "AWS::S3::Bucket"
        Properties = { BucketName = var.bucket_name }
      }
    }
    Outputs = {
      Name = { Value = { Ref = "Bucket" } }
      Arn  = { Value = { "Fn::GetAtt" = ["Bucket", "Arn"] } }
    }
  })

  tags = var.tags
}

# Al destruir, vacía el bucket antes de que CloudFormation intente borrarlo
# (un bucket con objetos o versiones no se puede borrar).
resource "terraform_data" "vaciar" {
  count = var.empty_on_destroy ? 1 : 0

  # En un provisioner de destroy solo se puede leer "self": por eso el nombre
  # del bucket y la ruta del script viajan dentro de input.
  input = {
    bucket = var.bucket_name
    script = "${path.module}/../../../scripts/vaciar-bucket.sh"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "bash ${self.input.script} ${self.input.bucket}"
  }

  depends_on = [aws_cloudformation_stack.bucket]
}

resource "aws_s3_bucket_versioning" "this" {
  count  = var.versioning ? 1 : 0
  bucket = aws_cloudformation_stack.bucket.outputs["Name"]

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_cloudformation_stack.bucket.outputs["Name"]

  rule {
    bucket_key_enabled = var.kms_key_arn != null

    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_cloudformation_stack.bucket.outputs["Name"]
  block_public_acls       = var.block_public_access
  block_public_policy     = var.block_public_access
  ignore_public_acls      = var.block_public_access
  restrict_public_buckets = var.block_public_access
}

resource "aws_s3_bucket_policy" "this" {
  count  = length(local.policy_statements) > 0 ? 1 : 0
  bucket = aws_cloudformation_stack.bucket.outputs["Name"]

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.policy_statements
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}

resource "aws_s3_bucket_website_configuration" "this" {
  count  = var.website_index_document != null ? 1 : 0
  bucket = aws_cloudformation_stack.bucket.outputs["Name"]

  index_document {
    suffix = var.website_index_document
  }

  error_document {
    key = var.website_index_document
  }
}

resource "aws_s3_bucket_cors_configuration" "this" {
  count  = length(var.cors_rules) > 0 ? 1 : 0
  bucket = aws_cloudformation_stack.bucket.outputs["Name"]

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      allowed_headers = cors_rule.value.allowed_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_cloudformation_stack.bucket.outputs["Name"]

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = "Enabled"

      filter {}

      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days != null ? [rule.value.expiration_days] : []
        content {
          days = expiration.value
        }
      }

      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_expiration_days != null ? [rule.value.noncurrent_expiration_days] : []
        content {
          noncurrent_days = noncurrent_version_expiration.value
        }
      }

      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_multipart_days != null ? [rule.value.abort_multipart_days] : []
        content {
          days_after_initiation = abort_incomplete_multipart_upload.value
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
