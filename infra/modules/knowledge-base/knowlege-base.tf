resource "aws_iam_role" "kb_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "kb_policy" {
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
          "secretsmanager:GetSecretValue",
        ]
        Resource = aws_secretsmanager_secret.kb_creds.arn
      },
      {
        "Action" : [
          "bedrock:InvokeModel"
        ],
        "Effect" : "Allow",
        "Resource" : local.embedding_model_arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.kb_bucket.arn,
          "${aws_s3_bucket.kb_bucket.arn}/*"
        ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "rds-data:ExecuteStatement",
          "rds-data:BatchExecuteStatement",
          "rds:DescribeDBClusters"
        ],
        "Resource" : aws_rds_cluster.rds_cluster.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "kb_role_attachment" {
  role       = aws_iam_role.kb_role.name
  policy_arn = aws_iam_policy.kb_policy.arn
}

resource "aws_bedrockagent_knowledge_base" "this" {

  name     = "${var.application}-${var.environment}-kb"
  role_arn = aws_iam_role.kb_role.arn

  knowledge_base_configuration {
    vector_knowledge_base_configuration {
      embedding_model_arn = local.embedding_model_arn
    }
    type = "VECTOR"
  }

  storage_configuration {
    type = "RDS"
    rds_configuration {
      credentials_secret_arn = aws_secretsmanager_secret.kb_creds.arn
      database_name          = aws_rds_cluster.rds_cluster.database_name
      resource_arn           = aws_rds_cluster.rds_cluster.arn
      table_name             = "${local.db_schema}.${local.vector_table}"
      field_mapping {
        primary_key_field = "id"
        metadata_field    = "metadata"
        text_field        = "chunks"
        vector_field      = "embedding"
      }
    }
  }

  depends_on = [
    aws_rds_cluster_instance.rds_cluster_instance,
    aws_lambda_invocation.seed_db_function,
    aws_secretsmanager_secret.kb_creds
  ]
}

resource "aws_bedrockagent_data_source" "this" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.this.id
  name              = "kb_datasource"

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 300
        overlap_percentage = 20
      }
    }
  }

  data_source_configuration {

    type = "S3"
    s3_configuration {

      bucket_arn         = aws_s3_bucket.kb_bucket.arn
      inclusion_prefixes = ["${local.kb_folder}"]
    }
  }
}

resource "aws_secretsmanager_secret" "kb_creds" {
  name        = "${var.application}-${var.environment}-kb-creds-${random_pet.this.id}"
  description = "Secret to be used for the knowledge base"
}
