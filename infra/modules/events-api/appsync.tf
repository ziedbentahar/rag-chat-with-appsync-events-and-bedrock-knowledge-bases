resource "awscc_iam_role" "appsync" {
  role_name = "${var.application}-${var.environment}-appsync-role"
  assume_role_policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "appsync.amazonaws.com"
        }
      }
    ]
  })

  policies = [
    {
      policy_name = "${var.application}-${var.environment}-appsync-logs"
      policy_document = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Effect = "Allow"
            Action = [
              "logs:CreateLogGroup",
              "logs:CreateLogStream",
              "logs:PutLogEvents"
            ]
            Resource = [
              "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/appsync/*:*"
            ]
          }
        ]
      })
    }
  ]
}

resource "awscc_appsync_api" "this" {
  name          = "${var.application}-${var.environment}-events-api"
  owner_contact = "${var.application}-${var.environment}"
  event_config = {
    auth_providers = [
      {
        auth_type = "AMAZON_COGNITO_USER_POOLS"
        cognito_config = {
          aws_region   = data.aws_region.current.name,
          user_pool_id = var.user_pool_id,
        }
      },
      {
        auth_type = "AWS_IAM"
      }
    ]
    connection_auth_modes = [
      {
        auth_type = "AMAZON_COGNITO_USER_POOLS"
      }
    ]
    default_publish_auth_modes = [
      {
        auth_type = "AMAZON_COGNITO_USER_POOLS"
      }
    ]
    default_subscribe_auth_modes = [
      {
        auth_type = "AMAZON_COGNITO_USER_POOLS"
      }
    ]
  }
}

