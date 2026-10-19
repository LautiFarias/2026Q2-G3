output "bucket_id" {
  value = aws_cloudformation_stack.bucket.outputs["Name"]
}

output "bucket_arn" {
  value = aws_cloudformation_stack.bucket.outputs["Arn"]
}

output "website_endpoint" {
  description = "Endpoint del sitio estático, o null si el bucket no tiene website."
  value       = one(aws_s3_bucket_website_configuration.this[*].website_endpoint)
}
