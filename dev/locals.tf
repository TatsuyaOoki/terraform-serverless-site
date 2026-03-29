locals {
  project   = "study"
  env       = "dev"
  origin_id = "webS3Origin"
}

data "aws_caller_identity" "self" {}
