# Subnet group for RDS
resource "aws_db_subnet_group" "this" {
  name       = "${local.name}-db-subnet"
  subnet_ids = var.private_subnets
}

# Security group for RDS MySQL
resource "aws_security_group" "rds" {
  name        = "${local.name}-rds-sg"
  vpc_id      = var.vpc_id
  description = "Security group for RDS MySQL instance"
}

# Security group rule to allow MySQL access from ECS tasks
resource "aws_security_group_rule" "rds_ingress_ecs" {
  security_group_id        = aws_security_group.rds.id
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "Allow MySQL access from ECS tasks"
}

# RDS MySQL instance with managed master password
resource "aws_db_instance" "this" {
  identifier        = "${local.name}-mysql"
  engine            = "mysql"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  db_name           = var.db_name

  username                    = "admin"
  manage_master_user_password = true

  skip_final_snapshot = true
  multi_az            = false

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.this.name
}
