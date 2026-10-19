output "state_bucket_name" {
  value = module.state_bucket.bucket_id
}

output "state_bucket_arn" {
  value = module.state_bucket.bucket_arn
}

output "lock_table_name" {
  description = "Nombre de la tabla DynamoDB de locks, o null si no se creó (one() sobre un recurso con count)."
  value       = one(aws_dynamodb_table.tf_locks[*].name)
}
