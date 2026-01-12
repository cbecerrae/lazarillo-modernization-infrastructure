# Data Sources
data "aws_region" "current" {}

# Data source for PostgreSQL Secrets Manager secret
data "aws_secretsmanager_secret" "postgresql" {
  name = var.db_secret_name
}

# ECS cluster for PostgreSQL
resource "aws_ecs_cluster" "this" {
  name = "${local.name}-cluster"
}

# Security group for ECS cluster
resource "aws_security_group" "ecs_cluster" {
  name        = "${local.name}-ecs-cluster-sg"
  vpc_id      = var.vpc_id
  description = "Security group for ECS cluster"
}

# Allow ingress PostgreSQL traffic from Nominatim ECS tasks to ECS Cluster
resource "aws_security_group_rule" "ecs_cluster_ingress_app" {
  security_group_id        = aws_security_group.ecs_cluster.id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.nominatim_ecs_tasks_sg_id
  description              = "Allow PostgreSQL access from Nominatim ECS tasks"
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

# ECS capacity provider using Managed Instances
resource "aws_ecs_capacity_provider" "managed_instances" {
  name    = "${local.name}-ecs-managed-instances-capacity-provider"
  cluster = aws_ecs_cluster.this.name

  managed_instances_provider {
    infrastructure_role_arn = aws_iam_role.ecs_infrastructure_role.arn
    propagate_tags          = "CAPACITY_PROVIDER"

    instance_launch_template {
      ec2_instance_profile_arn = aws_iam_instance_profile.ecs_instance.arn
      monitoring               = "BASIC"

      network_configuration {
        subnets         = var.private_subnets
        security_groups = [aws_security_group.ecs_cluster.id]
      }

      storage_configuration {
        storage_size_gib = 30
      }
    }
  }
}

# Attach capacity provider to ECS cluster
resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = [aws_ecs_capacity_provider.managed_instances.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.managed_instances.name
    base              = 0
    weight            = 100
  }
}

# Security group for ECS tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${local.name}-ecs-tasks-sg"
  vpc_id      = var.vpc_id
  description = "Security group for ECS tasks"
}

# Allow ingress traffic from Nominatim ECS tasks to PostgreSQL ECS tasks
resource "aws_security_group_rule" "ecs_tasks_ingress_app" {
  security_group_id        = aws_security_group.ecs_tasks.id
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.nominatim_ecs_tasks_sg_id
  description              = "Allow PostgreSQL access from Nominatim ECS tasks"
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

# ECS task definition for PostgreSQL
resource "aws_ecs_task_definition" "this" {
  family                   = local.name
  requires_compatibilities = ["MANAGED_INSTANCES"]
  network_mode             = "awsvpc"
  cpu                      = var.container_cpu
  memory                   = var.container_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  # Host-based volume backed by EBS (must be mounted on the EC2 instances)
  volume {
    name = "postgres-data"
    host_path  = "/mnt/postgres-data"
  }

  container_definitions = jsonencode([
    {
      name      = "postgresql"
      image     = "postgres:16"
      essential = true

      linuxParameters = {
        initProcessEnabled = true
      }

      portMappings = [
        {
          containerPort = 5432
          hostPort      = 5432
          protocol      = "tcp"
        }
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      environment = [
        { name = "PGDATA", value = "/var/lib/postgresql/data/pgdata" }
      ]

      secrets = [
        {
          name      = "POSTGRES_USER"
          valueFrom = "${data.aws_secretsmanager_secret.postgresql.arn}:username::"
        },
        {
          name      = "POSTGRES_PASSWORD"
          valueFrom = "${data.aws_secretsmanager_secret.postgresql.arn}:password::"
        },
        {
          name      = "POSTGRES_DB"
          valueFrom = "${data.aws_secretsmanager_secret.postgresql.arn}:dbname::"
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "postgres-data"
          containerPath = "/var/lib/postgresql/data"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.name}"
          awslogs-region        = data.aws_region.current.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "ecs_cw_logs" {
  name              = "/ecs/${local.name}"
  retention_in_days = 7
}

# ECS service for PostgreSQL using Cloud Map
resource "aws_ecs_service" "this" {
  name                    = local.name
  cluster                 = aws_ecs_cluster.this.id
  task_definition         = aws_ecs_task_definition.this.arn
  desired_count           = 1
  enable_execute_command  = true
  force_new_deployment    = true
  enable_ecs_managed_tags = true

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.managed_instances.name
    weight            = 1
  }

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [aws_security_group.ecs_tasks.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.postgresql.arn
    container_name = "postgresql"
  }
}

# Service Discovery Namespace
resource "aws_service_discovery_private_dns_namespace" "postgresql" {
  name        = "${local.name}.ecs.internal"
  description = "ECS internal namespace with private hosted zone in Route53"
  vpc         = var.vpc_id
}

# Cloud Map service for PostgreSQL
resource "aws_service_discovery_service" "postgresql" {
  name = "postgresql"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.postgresql.id

    dns_records {
      type = "A"
      ttl  = 10
    }
  }
}
