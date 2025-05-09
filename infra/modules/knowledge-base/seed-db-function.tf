resource "aws_iam_role" "seed_db_function" {
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

resource "aws_iam_policy" "seed_db_function" {
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
          "secretsmanager:GetSecretValue",
        ]
        Resource = data.aws_secretsmanager_secret.db_secret.arn
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:PutSecretValue",
        ]
        Resource = aws_secretsmanager_secret.kb_creds.arn
      },
      {
        "Sid" : "RDSDataServiceAccess",
        "Effect" : "Allow",
        "Action" : [
          "rds-data:BatchExecuteStatement",
          "rds-data:ExecuteStatement",
          "rds-data:BeginTransaction",
          "rds-data:CommitTransaction",
          "rds-data:RollbackTransaction"
        ],
        "Resource" : aws_rds_cluster.rds_cluster.arn
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "seed_db_function" {
  role       = aws_iam_role.seed_db_function.name
  policy_arn = aws_iam_policy.seed_db_function.arn
}

data "archive_file" "seed_db_function" {
  type        = "zip"
  source_dir  = var.seed_db_function.dist_dir
  output_path = "${path.root}/.terraform/tmp/lambda-dist-zips/${var.seed_db_function.name}.zip"
}

resource "aws_lambda_function" "seed_db_function" {
  function_name    = "${var.application}-${var.environment}-${var.seed_db_function.name}"
  filename         = data.archive_file.seed_db_function.output_path
  role             = aws_iam_role.seed_db_function.arn
  handler          = var.seed_db_function.handler
  source_code_hash = filebase64sha256("${data.archive_file.seed_db_function.output_path}")
  runtime          = "nodejs22.x"
  memory_size      = "256"
  architectures    = ["arm64"]

  logging_config {
    system_log_level      = "WARN"
    application_log_level = "INFO"
    log_format            = "JSON"
  }

  environment {
    variables = {
      DB_SECRET_ARN       = data.aws_secretsmanager_secret.db_secret.arn
      DB_ARN              = aws_rds_cluster.rds_cluster.arn
      DB_NAME             = aws_rds_cluster.rds_cluster.database_name
      KB_CREDS_SECRET_ARN = aws_secretsmanager_secret.kb_creds.arn
    }
  }
}

resource "aws_cloudwatch_log_group" "seed_db_function" {
  name              = "/aws/lambda/${aws_lambda_function.seed_db_function.function_name}"
  retention_in_days = "3"
}

resource "aws_lambda_invocation" "seed_db_function" {

  function_name = aws_lambda_function.seed_db_function.function_name
  input = jsonencode({
    db_schema    = local.db_schema
    vector_table = local.vector_table
  })

  depends_on = [
    aws_lambda_function.seed_db_function,
    aws_rds_cluster_instance.rds_cluster_instance
  ]

  lifecycle_scope = "CREATE_ONLY"

}
