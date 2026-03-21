# -----------------------------------
# S3
# -----------------------------------
resource "aws_s3_bucket" "content" {
  force_destroy = true
  bucket        = "${local.project}-${local.env}-content-bucket-${data.aws_caller_identity.self.account_id}"
}

resource "aws_s3_bucket" "web" {
  force_destroy = true
  bucket        = "${local.project}-${local.env}-web-bucket-${data.aws_caller_identity.self.account_id}"

}


# -----------------------------------
# DynamoDB
# -----------------------------------
resource "aws_dynamodb_table" "album" {
  name         = "${local.project}-${local.env}-album-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "photoId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "photoId"
    type = "S"
  }
}