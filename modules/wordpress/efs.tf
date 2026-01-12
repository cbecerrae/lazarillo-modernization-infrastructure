# EFS file system for WordPress shared storage
resource "aws_efs_file_system" "this" {
  encrypted = true

  tags = {
    Name = "${local.name}-efs"
  }
}

# Security group for EFS mount targets
resource "aws_security_group" "efs" {
  name        = "${local.name}-efs-sg"
  vpc_id      = var.vpc_id
  description = "Security group for EFS mount targets"
}

# Security group rule to allow NFS access from ECS tasks
resource "aws_security_group_rule" "efs_ingress_ecs" {
  security_group_id        = aws_security_group.efs.id
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "Allow NFS access from ECS tasks"
}

# EFS mount targets in private subnets
resource "aws_efs_mount_target" "this" {
  for_each        = toset(var.private_subnets)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}
