variable "project" {
  type    = string
  default = "accesoseguro"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket_name" {
  description = "Nombre del bucket del state. Si queda vacío, se genera uno único con el account id."
  type        = string
  default     = ""
}

variable "create_dynamodb_lock_table" {
  description = "Terraform >= 1.10 bloquea el state con un .tflock en el propio bucket S3. Esta tabla es el método clásico, se deja como opción."
  type        = bool
  default     = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
