terraform {
  required_version = ">=1.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  backend "s3" {
    bucket       = "terraform-state-bucket-0343"
    key          = "terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true
  }
}

provider "aws" {
  # alias  = "develop"
  region = "ap-northeast-1"

  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "terraform"
  default_tags {
    tags = {
      Environment = local.env
      CreatedBy   = "terraform"
    }
  }
}

