locals {
  project = "study"
  env     = "dev"
}

data "aws_caller_identity" "self" {}
