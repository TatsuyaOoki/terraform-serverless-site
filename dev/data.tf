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