# Lambda IAM Role

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
        Resource = "arn:aws:s3:::${aws_s3_bucket.web_bucket.bucket}/*"
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


# Lambda

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
      "BUCKET_NAME" = aws_s3_bucket.web_bucket.bucket
    }
  }
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_url_lambda.function_name
  principal     = "apigateway.amazonaws.com"
}

# API Gateway

resource "aws_apigatewayv2_api" "main" {
  name          = "${local.project}-${local.env}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.main.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.create_url_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "create_s3_url" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /create-url"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true
}