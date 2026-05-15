###############################################################################
# modules/rds/main.tf
#
# Managed relational database:
#   * KMS CMK for storage + backups encryption
#   * DB subnet group across two private data subnets
#   * Security group accepting MySQL 3306 only from the web tier SG
#   * Multi-AZ MySQL 8.0 instance with 7-day backups and deletion protection
###############################################################################

# ---- KMS key for RDS storage encryption -----------------------------------
resource "aws_kms_key" "rds" {
  description             = "${var.name_prefix} RDS storage encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = merge(var.tags, { Name = "${var.name_prefix}-rds-kms" })
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.name_prefix}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

# ---- DB subnet group ------------------------------------------------------
resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-db-subnets"
  subnet_ids = var.private_data_subnet_ids
  tags       = merge(var.tags, { Name = "${var.name_prefix}-db-subnets" })
}

# ---- SG: accept 3306 only from the web tier SG ---------------------------
resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-db-sg"
  description = "Allow MySQL from the web tier."
  vpc_id      = var.vpc_id

  ingress {
    description     = "MySQL from web tier"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [var.app_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-db-sg" })
}

# ---- Parameter group (enables stricter defaults) -------------------------
resource "aws_db_parameter_group" "mysql8" {
  name   = "${var.name_prefix}-mysql8-params"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }
  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-mysql8-params" })
}

# ---- RDS instance (Multi-AZ) ---------------------------------------------
resource "aws_db_instance" "this" {
  identifier        = "${var.name_prefix}-db"
  engine            = "mysql"
  engine_version    = var.engine_version
  instance_class    = var.instance_class
  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 3306

  multi_az               = true
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.mysql8.name

  backup_retention_period = var.backup_retention_days
  backup_window           = "02:00-03:00"
  maintenance_window      = "sun:03:30-sun:05:00"

  deletion_protection       = true
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.name_prefix}-db-final"
  copy_tags_to_snapshot     = true

  performance_insights_enabled = true
  monitoring_interval          = 60

  tags = merge(var.tags, { Name = "${var.name_prefix}-db" })
}
