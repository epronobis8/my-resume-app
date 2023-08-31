provider "aws" {
  #region is set as a variable
  region = var.aws_region
}

locals {
  owner               = "Erin"
  product_status_code = "200"
}

################################################################################
# DynamoDB creation
################################################################################

resource "aws_dynamodb_table" "resume-db" {
  name           = var.dynamodb-name
  hash_key       = "productId"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1

  attribute {
    name = "productId"
    type = "S"
  }
  tags = {
    Environment = var.envTag
    IaC         = "true"
  }
}

################################################################################
# Creating REST API
################################################################################

resource "aws_api_gateway_rest_api" "my-resume-api" {
  name        = var.api-name
  description = "REST API Gateway integration with DynamoDB."

  tags = {
    IaC         = "true"
    Environment = var.envTag
  }
}

resource "aws_api_gateway_resource" "count-api" {
  parent_id   = aws_api_gateway_rest_api.my-resume-api.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.my-resume-api.id
  path_part   = "count"
}

resource "aws_api_gateway_method" "api-method" {
  rest_api_id   = aws_api_gateway_rest_api.my-resume-api.id
  resource_id   = aws_api_gateway_resource.count-api.id
  http_method   = "ANY"
  authorization = "NONE"
  #api_key_required = true
}

resource "aws_api_gateway_integration" "api-integration" {
  rest_api_id             = aws_api_gateway_rest_api.my-resume-api.id
  resource_id             = aws_api_gateway_resource.count-api.id
  http_method             = aws_api_gateway_method.api-method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda.invoke_arn
  request_templates = {
    "application/json" = ""
  }
  depends_on = [
    aws_api_gateway_resource.count-api,
    aws_api_gateway_method.api-method
  ]
}

resource "aws_api_gateway_method_response" "api-response" {
  rest_api_id = aws_api_gateway_rest_api.my-resume-api.id
  resource_id = aws_api_gateway_resource.count-api.id
  http_method = aws_api_gateway_method.api-method.http_method
  status_code = local.product_status_code

  response_models = {
    "application/json" = "Empty"
  }
}

################################################################################
# API GW Deployment
################################################################################


resource "aws_api_gateway_deployment" "deploy" {
  rest_api_id = aws_api_gateway_rest_api.my-resume-api.id

  depends_on = [
    aws_api_gateway_method.api-method,
    aws_api_gateway_integration.api-integration
  ]
}

#Deployment stage of your API. When hitting the Invoke URL you will add /stage
resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deploy.id
  rest_api_id   = aws_api_gateway_rest_api.my-resume-api.id
  stage_name    = var.stage-name
  description   = "My resume app prod deployment"
  tags = {
    "IaC"         = "true"
    "Environment" = var.envTag
  }
}

################################################################################
# IAM role for Lambda to access CloudWatch logs & DynamoDB
################################################################################

resource "aws_iam_role" "lambda-access-dynamodb" {
  name        = "lambda-dynamodb-iam-role"
  description = "Allows Lambda functions to call AWS services on your behalf. Access to CloudWatch logs for troubleshooting and dynamodb for backend db."
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}


resource "aws_iam_role_policy" "access-policy" {
  name   = "lambda-access-dynmaodb-policy"
  role   = aws_iam_role.lambda-access-dynamodb.id
  policy = <<-EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:DescribeTable",
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem"
            ],
            "Resource": "${aws_dynamodb_table.resume-db.arn}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "logs:CreateLogGroup",
            "Resource": "*"
      }
    ]
  }
  EOF
}

################################################################################
# Lambda Function
################################################################################

resource "aws_lambda_permission" "permissions" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"
}

data "archive_file" "zip_code" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/"
  output_path = "${path.module}/lambda/lambda.zip"
}

resource "aws_lambda_function" "lambda" {
  function_name = "my-resume-lambda_function"
  filename      = "${path.module}/lambda/lambda.zip"
  role          = aws_iam_role.lambda-access-dynamodb.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
}

################################################################################
# Lambda & API Gateway Logging
################################################################################

#Enable CW logging for Lambda
resource "aws_cloudwatch_log_group" "lambda-logs" {
  name              = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 30
}

#added API GW logging
resource "aws_api_gateway_method_settings" "api-logs" {
  rest_api_id = aws_api_gateway_rest_api.my-resume-api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

################################################################################
# S3 Bucket
################################################################################

resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket

  tags = {
    Environment = var.envTag
    "IAC" = "true"
  }
}

