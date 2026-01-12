# Data Sources
data "aws_region" "current" {}

# ECS cluster for WordPress
resource "aws_ecs_cluster" "this" {
  name = "${local.name}-cluster"
}

# Security group for ECS cluster
resource "aws_security_group" "ecs_cluster" {
  name        = "${local.name}-ecs-cluster-sg"
  vpc_id      = var.vpc_id
  description = "Security group for ECS cluster"
}

# Allow ingress traffic from ALB to ECS Cluster
resource "aws_security_group_rule" "ecs_cluster_ingress_alb" {
  security_group_id        = aws_security_group.ecs_cluster.id
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow HTTP access from ALB to ECS cluster"
}

# Allow egress internet access from ECS Cluster
resource "aws_security_group_rule" "ecs_cluster_egress_internet" {
  security_group_id = aws_security_group.ecs_cluster.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound internet traffic from ECS cluster"
}

# # # ECS capacity provider using Managed Instances
# # resource "aws_ecs_capacity_provider" "managed_instances" {
# #   name    = "${local.name}-ecs-managed-instances-capacity-provider"
# #   cluster = aws_ecs_cluster.this.name

# #   managed_instances_provider {
# #     infrastructure_role_arn = aws_iam_role.ecs_infrastructure_role.arn
# #     propagate_tags          = "CAPACITY_PROVIDER"

# #     instance_launch_template {
# #       ec2_instance_profile_arn = aws_iam_instance_profile.ecs_instance.arn
# #       monitoring               = "BASIC"

# #       network_configuration {
# #         subnets         = var.private_subnets
# #         security_groups = [aws_security_group.ecs_cluster.id]
# #       }

# #       storage_configuration {
# #         storage_size_gib = 30
# #       }
# #     }
# #   }
# # }

# # # Attach Managed Instances capacity provider to ECS cluster
# # resource "aws_ecs_cluster_capacity_providers" "this" {
# #   cluster_name = aws_ecs_cluster.this.name

# #   capacity_providers = [aws_ecs_capacity_provider.managed_instances.name]

# #   default_capacity_provider_strategy {
# #     capacity_provider = aws_ecs_capacity_provider.managed_instances.name
# #     base              = 0
# #     weight            = 100
# #   }
# # }

# Attach Fargate capacity provider to ECS cluster
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# Security group for ECS tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name}-ecs-tasks-sg"
  vpc_id      = var.vpc_id
  description = "Security group for ECS tasks"
}

# Allow ingress traffic from ALB to ECS tasks
resource "aws_security_group_rule" "ecs_tasks_ingress_alb" {
  security_group_id        = aws_security_group.ecs_tasks.id
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description              = "Allow HTTP access from ALB to ECS tasks"
}

# Allow egress internet access from ECS tasks
resource "aws_security_group_rule" "ecs_tasks_egress_internet" {
  security_group_id = aws_security_group.ecs_tasks.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow outbound internet traffic"
}

# ECS task definition for WordPress
resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  requires_compatibilities = ["MANAGED_INSTANCES"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  volume {
    name = "wordpress-efs"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.this.id
      root_directory = "/"
    }
  }

  container_definitions = jsonencode([{
    name  = "wordpress"
    image = "wordpress:latest"

    essential = true

    linuxParameters = {
      initProcessEnabled = true
    }

    portMappings = [{
      containerPort = 80
      hostPort      = 80
      protocol      = "tcp"
    }]

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost/wp-login.php || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    environment = [
      { name = "WORDPRESS_DB_HOST", value = aws_db_instance.this.address },
      { name = "WORDPRESS_DB_NAME", value = var.db_name }
    ]

    secrets = [
      {
        name      = "WORDPRESS_DB_USER"
        valueFrom = "${aws_db_instance.this.master_user_secret[0].secret_arn}:username::"
      },
      {
        name      = "WORDPRESS_DB_PASSWORD"
        valueFrom = "${aws_db_instance.this.master_user_secret[0].secret_arn}:password::"
      }
    ]

    mountPoints = [{
      sourceVolume  = "wordpress-efs"
      containerPath = "/var/www/html/wp-content"
    }]

    logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.name}"
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "ecs"
        }
      }
  }])
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "ecs_cw_logs" {
  name              = "/ecs/${local.name}"
  retention_in_days = 7
}

# ECS service exposing WordPress through ALB
resource "aws_ecs_service" "this" {
  name                    = local.name
  cluster                 = aws_ecs_cluster.this.id
  task_definition         = aws_ecs_task_definition.this.arn
  desired_count           = 2
  enable_execute_command  = true
  force_new_deployment    = true
  enable_ecs_managed_tags = true

  # capacity_provider_strategy {
  #   capacity_provider = aws_ecs_capacity_provider.managed_instances.name
  #   weight            = 1
  # }

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "wordpress"
    container_port   = 80
  }
}
