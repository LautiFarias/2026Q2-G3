data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

# El Learner Lab no deja crear roles IAM propios: ECS y las Lambdas usan
# este rol compartido (task role y execution role).
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}
