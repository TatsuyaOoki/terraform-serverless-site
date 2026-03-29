# -----------------------------------
# IAM Role
# -----------------------------------

resource "aws_iam_role" "lambda" {
  name = "LambdaS3Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_access_policy" {
  name = "lambda_s3_access_policy"
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "S3:PutObject"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:s3:::${aws_s3_bucket.web.bucket}/*"
      },
      {
        Action = [
          "dynamodb:PutItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.album.arn
      },
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*"
      }
    ]
  })
}


# -----------------------------------
# Lambda
# -----------------------------------

data "archive_file" "api_gateway_lambda_code" {
  type        = "zip"
  source_dir  = "data/lambda"
  output_path = "data/lambda/apigateway_function.zip"
}

resource "aws_lambda_function" "create_url_lambda" {
  function_name    = "create-s3-url"
  filename         = data.archive_file.api_gateway_lambda_code.output_path
  source_code_hash = data.archive_file.api_gateway_lambda_code.output_base64sha256
  runtime          = "python3.12"
  handler          = "create_s3_url.lambda_handler"
  role             = aws_iam_role.lambda.arn
  environment {
    variables = {
      "BUCKET_NAME" = aws_s3_bucket.web.bucket
    }
  }
}

resource "aws_lambda_permission" "create_url_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_url_lambda.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_lambda_function" "save_metadata" {
  function_name    = "save-dynamodb-metadata"
  filename         = data.archive_file.api_gateway_lambda_code.output_path
  source_code_hash = data.archive_file.api_gateway_lambda_code.output_base64sha256
  runtime          = "python3.12"
  handler          = "save_metadata_dynamodb.lambda_handler"
  role             = aws_iam_role.lambda.arn
  environment {
    variables = {
      "TABLE_NAME" = aws_dynamodb_table.album.name
    }
  }
}

resource "aws_lambda_permission" "save_metadata" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.save_metadata.function_name
  principal     = "apigateway.amazonaws.com"
}

# -----------------------------------
# API Gateway
# -----------------------------------

resource "aws_apigatewayv2_api" "main" {
  name          = "${local.project}-${local.env}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["*"]
  }
}

## create-url

resource "aws_apigatewayv2_integration" "create_url_lambda" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.create_url_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "create_s3_url" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /create-url"
  target    = "integrations/${aws_apigatewayv2_integration.create_url_lambda.id}"
}

## save-metadata

resource "aws_apigatewayv2_integration" "save_metadata" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.save_metadata.invoke_arn
}

resource "aws_apigatewayv2_route" "save_metadata" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /save-metadata"
  target    = "integrations/${aws_apigatewayv2_integration.save_metadata.id}"
}

resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}

# -----------------------------------
# S3
# -----------------------------------

# S3 Bucket
resource "aws_s3_bucket" "web" {
  force_destroy = true
  bucket        = "${local.project}-${local.env}-web-bucket-${data.aws_caller_identity.self.account_id}"

}


# Bucket Policy
data "aws_iam_policy_document" "web_bucket_security" {
  statement {
    effect = "Deny"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.web.arn,
      "${aws_s3_bucket.web.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

data "aws_iam_policy_document" "web_bucket_cloudfront_access" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions = ["s3:GetObject"]
    resources = [
      "${aws_s3_bucket.web.arn}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main.arn]
    }
  }
}

data "aws_iam_policy_document" "web_bucket_policy" {
  override_policy_documents = [
    data.aws_iam_policy_document.web_bucket_security.json,
    data.aws_iam_policy_document.web_bucket_cloudfront_access.json
  ]
}

resource "aws_s3_bucket_policy" "web_bucket" {
  bucket = aws_s3_bucket.web.id
  policy = data.aws_iam_policy_document.web_bucket_policy.json
}

# -----------------------------------
# CloudFront
# -----------------------------------
resource "aws_cloudfront_origin_access_control" "main" {
  name                              = "web-s3-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}


resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name              = aws_s3_bucket.web.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.main.id
    origin_id                = local.origin_id
  }

  default_cache_behavior {
    target_origin_id       = local.origin_id
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  enabled             = true
  is_ipv6_enabled     = false
  price_class         = "PriceClass_200"
  default_root_object = "index.html"

}