# Módulo `s3-bucket`

Bucket S3 con versionado, cifrado (KMS o AES256), bloqueo de acceso público,
bucket policy, CORS, ciclo de vida y sitio web estático opcionales.

El bucket en sí se crea con un stack de CloudFormation (`aws_cloudformation_stack`)
porque en AWS Academy una SCP deniega `s3:GetBucketObjectLockConfiguration` y
`aws_s3_bucket` falla siempre al leer el bucket. Todo lo demás son recursos
`aws_s3_bucket_*` normales.
