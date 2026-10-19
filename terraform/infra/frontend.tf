## Sitio estático: un bucket S3 con lectura pública (solo GetObject) que
## sirve las pantallas. El navegador descarga HTML/CSS/JS y le pide los
## datos a la API vía el ALB.

# El endpoint website de S3 solo habla HTTP: con deny_insecure_transport el
# sitio devolvería 403, por eso acá va en false.
module "sitio" {
  source = "../modules/s3-bucket"

  bucket_name             = "${local.name_prefix}-sitio"
  website_index_document  = "index.html"
  block_public_access     = false
  public_read             = true
  deny_insecure_transport = false
  tags                    = merge(local.common_tags, { Name = "${local.name_prefix}-sitio" })
}

locals {
  # fileset()+setsubtract(): todos los archivos del front menos la plantilla
  # (que se sube aparte, ya resuelta con templatefile()).
  frontend_dir = "${path.root}/../../frontend"
  frontend_files = setsubtract(
    fileset(local.frontend_dir, "**"),
    fileset(local.frontend_dir, "*.tftpl")
  )

  mime_types = {
    html = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    json = "application/json"
    png  = "image/png"
    jpg  = "image/jpeg"
    svg  = "image/svg+xml"
    ico  = "image/x-icon"
  }

  sitio_origin = format("http://%s.s3-website-%s.amazonaws.com", module.sitio.bucket_id, var.region)
}

resource "aws_s3_object" "frontend" {
  for_each = local.frontend_files

  bucket = module.sitio.bucket_id
  key    = each.value
  source = "${local.frontend_dir}/${each.value}"
  etag   = filemd5("${local.frontend_dir}/${each.value}") # solo se re-sube si cambió

  # lookup()+split()+element()+length()+lower(): Content-Type según la extensión.
  content_type = lookup(
    local.mime_types,
    lower(element(split(".", each.value), length(split(".", each.value)) - 1)),
    "application/octet-stream"
  )
}

# config.js lo arma Terraform con los valores reales del pool de Cognito y
# la URL del ALB: el front nunca tiene esos datos hardcodeados.
resource "aws_s3_object" "frontend_config" {
  bucket       = module.sitio.bucket_id
  key          = "config.js"
  content_type = "application/javascript"

  content = templatefile("${local.frontend_dir}/config.js.tftpl", {
    api_url               = "http://${aws_lb.main.dns_name}"
    cognito_user_pool_id  = aws_cognito_user_pool.main.id
    cognito_app_client_id = aws_cognito_user_pool_client.app.id
    cognito_region        = var.region
    environment           = var.environment
  })
}
