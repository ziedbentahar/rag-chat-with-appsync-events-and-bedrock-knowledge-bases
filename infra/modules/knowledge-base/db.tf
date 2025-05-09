resource "aws_security_group" "rds_sg" {
  name   = "${var.application}-${var.environment}-rds-sg"
  vpc_id = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_rds_cluster" "rds_cluster" {
  cluster_identifier          = "${var.application}-${var.environment}-db-cluster"
  engine                      = "aurora-postgresql"
  engine_mode                 = "provisioned"
  engine_version              = "16.4"
  database_name               = var.db.name
  master_username             = var.db.master_username
  manage_master_user_password = true

  storage_encrypted    = true
  db_subnet_group_name = var.db_subnet_group_name
  deletion_protection  = false
  skip_final_snapshot  = true
  apply_immediately    = true

  enable_http_endpoint = true

  serverlessv2_scaling_configuration {
    max_capacity = var.db.max_capacity
    min_capacity = var.db.min_capacity
  }

  vpc_security_group_ids = [aws_security_group.rds_sg.id]

}

resource "aws_rds_cluster_instance" "rds_cluster_instance" {
  cluster_identifier = aws_rds_cluster.rds_cluster.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.rds_cluster.engine
  engine_version     = aws_rds_cluster.rds_cluster.engine_version
  apply_immediately  = true

}

data "aws_secretsmanager_secret" "db_secret" {
  arn = aws_rds_cluster.rds_cluster.master_user_secret[0].secret_arn
}

