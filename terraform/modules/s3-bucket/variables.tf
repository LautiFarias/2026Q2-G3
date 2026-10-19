variable "bucket_name" {
  description = "Nombre del bucket (único a nivel global)."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "versioning" {
  type    = bool
  default = true
}

variable "kms_key_arn" {
  description = "Clave KMS para cifrar el bucket. Si es null se usa AES256."
  type        = string
  default     = null
}

variable "block_public_access" {
  description = "true: bloquea todo acceso público. false: lo permite (sitio estático)."
  type        = bool
  default     = true
}

variable "public_read" {
  description = "Agrega una política de lectura pública solo para s3:GetObject (requiere block_public_access = false)."
  type        = bool
  default     = false
}

variable "deny_insecure_transport" {
  description = "Rechaza cualquier pedido que no use HTTPS."
  type        = bool
  default     = true
}

variable "extra_policy_statements" {
  description = "Statements adicionales para la bucket policy (ej. CloudTrail)."
  type        = any
  default     = []
}

variable "website_index_document" {
  description = "Si no es null, el bucket sirve un sitio estático con este documento de inicio."
  type        = string
  default     = null
}

variable "cors_rules" {
  type = list(object({
    allowed_methods = list(string)
    allowed_origins = list(string)
    allowed_headers = optional(list(string), ["*"])
    max_age_seconds = optional(number, 3000)
  }))
  default = []
}

variable "lifecycle_rules" {
  type = list(object({
    id                         = string
    transitions                = optional(list(object({ days = number, storage_class = string })), [])
    expiration_days            = optional(number)
    noncurrent_expiration_days = optional(number)
    abort_multipart_days       = optional(number)
  }))
  default = []
}

variable "empty_on_destroy" {
  description = "Vacía el bucket (incluye versiones) antes de borrarlo. Útil en el lab; no usar en buckets que no se pueden perder."
  type        = bool
  default     = true
}
