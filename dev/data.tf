resource "aws_s3_bucket" "web_bucket" {
  force_destroy = true
  bucket = "${local.project}-${local.env}-web-bucket"
}