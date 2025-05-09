resource "aws_iam_role" "handle_appsync_events_function" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "handle_appsync_events_function" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = ["arn:aws:logs:*:*:*"]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:Retrieve",
          "bedrock:RetrieveAndGenerate",
        ]
        Resource = [var.knowledge_base.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",

        ]
        Resource = [var.knowledge_base.generation_model_arn]
      },
      {
        Effect = "Allow",
        Action = [
          "appsync:EventPublish",
        ],
        Resource = [
          "${awscc_appsync_api.this.id}/*"
        ]
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "handle_appsync_events_function" {
  role       = aws_iam_role.handle_appsync_events_function.name
  policy_arn = aws_iam_policy.handle_appsync_events_function.arn
}

data "archive_file" "handle_appsync_events_function" {
  type        = "zip"
  source_dir  = var.handle_appsync_events_function.dist_dir
  output_path = "${path.root}/.terraform/tmp/lambda-dist-zips/${var.handle_appsync_events_function.name}.zip"
}

resource "aws_lambda_function" "handle_appsync_events_function" {
  function_name    = "${var.application}-${var.environment}-${var.handle_appsync_events_function.name}"
  filename         = data.archive_file.handle_appsync_events_function.output_path
  role             = aws_iam_role.handle_appsync_events_function.arn
  handler          = var.handle_appsync_events_function.handler
  source_code_hash = filebase64sha256("${data.archive_file.handle_appsync_events_function.output_path}")
  runtime          = "nodejs22.x"
  memory_size      = "256"
  architectures    = ["arm64"]

  logging_config {
    system_log_level      = "WARN"
    application_log_level = "INFO"
    log_format            = "JSON"
  }

  timeout = 5 * 60

  environment {
    variables = {
      KB_ID : var.knowledge_base.id
      KB_MODEL_ARN : var.knowledge_base.generation_model_arn,
      EVENTS_API_DNS : awscc_appsync_api.this.dns.http,
    }
  }
}

resource "aws_cloudwatch_log_group" "handle_appsync_events_function" {
  name              = "/aws/lambda/${aws_lambda_function.handle_appsync_events_function.function_name}"
  retention_in_days = "3"
  lifecycle {
    prevent_destroy = false
  }
}


