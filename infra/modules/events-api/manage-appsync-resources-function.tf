resource "aws_iam_role" "manage_appsync_resources_function" {
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

resource "aws_iam_policy" "manage_appsync_resources_function" {
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
          "iam:PassRole",
        ]
        Resource = [aws_iam_role.appsync_service_role.arn]
      }

    ]
  })
}


resource "aws_iam_role_policy_attachment" "manage_appsync_resources_function" {
  role       = aws_iam_role.manage_appsync_resources_function.name
  policy_arn = aws_iam_policy.manage_appsync_resources_function.arn
}

resource "aws_iam_role_policy_attachment" "lambda_appsync_admin" {
  role       = aws_iam_role.manage_appsync_resources_function.name
  policy_arn = "arn:aws:iam::aws:policy/AWSAppSyncAdministrator"
}

data "archive_file" "manage_appsync_resources_function" {
  type        = "zip"
  source_dir  = var.manage_appsync_resources_function.dist_dir
  output_path = "${path.root}/.terraform/tmp/lambda-dist-zips/${var.manage_appsync_resources_function.name}.zip"
}

resource "aws_lambda_function" "manage_appsync_resources_function" {
  function_name    = "${var.application}-${var.environment}-${var.manage_appsync_resources_function.name}"
  filename         = data.archive_file.manage_appsync_resources_function.output_path
  role             = aws_iam_role.manage_appsync_resources_function.arn
  handler          = var.manage_appsync_resources_function.handler
  source_code_hash = filebase64sha256("${data.archive_file.manage_appsync_resources_function.output_path}")
  runtime          = "nodejs22.x"
  memory_size      = "256"
  architectures    = ["arm64"]

  logging_config {
    system_log_level      = "WARN"
    application_log_level = "INFO"
    log_format            = "JSON"
  }

  environment {
    variables = {}
  }
}

resource "aws_cloudwatch_log_group" "manage_appsync_resources_function" {
  name              = "/aws/lambda/${aws_lambda_function.manage_appsync_resources_function.function_name}"
  retention_in_days = "3"
}




resource "aws_iam_role" "appsync_service_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "appsync.amazonaws.com"
        }
        "Condition" = {
          "StringEquals" = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          },
          "ArnEquals" = {
            "aws:SourceArn" = awscc_appsync_api.this.id
          }
        }
      },
    ]
  })
}

resource "aws_iam_policy" "app_sync_service_role_policy" {
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Effect" = "Allow",
        "Action" = [
          "lambda:invokeFunction"
        ],
        "Resource" = [
          aws_lambda_function.handle_appsync_events_function.arn,
          "${aws_lambda_function.handle_appsync_events_function.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_sync_service_role_policy" {
  role       = aws_iam_role.appsync_service_role.name
  policy_arn = aws_iam_policy.app_sync_service_role_policy.arn
}

resource "aws_lambda_invocation" "manage_appsync_resources_function" {

  function_name = aws_lambda_function.manage_appsync_resources_function.function_name
  input = jsonencode({
    apiId : local.api_id
    dataSourceName : replace(aws_lambda_function.handle_appsync_events_function.function_name, "-", "")
    lambdaFunctionArn : aws_lambda_function.handle_appsync_events_function.arn
    serviceRoleArn : aws_iam_role.appsync_service_role.arn
    channelName : "chat"
  })

  depends_on = [
    aws_lambda_function.manage_appsync_resources_function,
    awscc_appsync_api.this
  ]

  lifecycle_scope = "CRUD"

}
