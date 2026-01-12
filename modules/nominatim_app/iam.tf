# IAM role for ECS task execution
resource "aws_iam_role" "ecs_execution_role" {
  name = "${local.name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach base ECS task execution permissions
resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM policy to allow reading database credentials from Secrets Manager
resource "aws_iam_role_policy" "secrets_manager_access" {
  name = "${local.name}-ecs-secrets-access"
  role = aws_iam_role.ecs_execution_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = ["*"]
      }
    ]
  })
}

# IAM role for the running ECS task
resource "aws_iam_role" "ecs_task_role" {
  name = "${local.name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Add additional task role policies as needed
resource "aws_iam_role_policy" "ecs_task_custom_policy" {
  name = "${local.name}-ecs-task-custom-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Resource = ["*"]
      },
      {
        Sid    = "VisualEditor0",
        Effect = "Allow",
        Action = [
          "ssmmessages:CreateDataChannel",
          "ecs:ExecuteCommand",
          "ssmmessages:OpenDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:CreateControlChannel",
          "ecs:DescribeTasks"
        ],
        Resource = "*"
      }
    ]
  })
}

# Create an IAM role that Amazon ECS can assume to manage cluster infrastructure (Managed Instances, volumes, etc.)
resource "aws_iam_role" "ecs_infrastructure_role" {
  name = "${local.name}-ecs-infrastructure-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Allow ECS Infrastructure Role to pass the ECS Instance Role
resource "aws_iam_role_policy" "ecs_infrastructure_pass_instance_role" {
  name = "${local.name}-ecs-infrastructure-pass-instance-role"
  role = aws_iam_role.ecs_infrastructure_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.ecs_instance.arn
      }
    ]
  })
}

# Attach the managed AWS policy that allows ECS to control Managed Instances
resource "aws_iam_role_policy_attachment" "infrastructure_managed_instances" {
  role       = aws_iam_role.ecs_infrastructure_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECSInfrastructureRolePolicyForManagedInstances"
}

# EBS volume management for tasks
resource "aws_iam_role_policy_attachment" "infrastructure_ebs_volumes" {
  role       = aws_iam_role.ecs_infrastructure_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRolePolicyForVolumes"
}

# ALB management for tasks
resource "aws_iam_role_policy_attachment" "infrastructure_alb_management" {
  role       = aws_iam_role.ecs_infrastructure_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECSInfrastructureRolePolicyForLoadBalancers"
}

# IAM role assumed by ECS EC2 instances (Managed Instances)
resource "aws_iam_role" "ecs_instance" {
  name = "${local.name}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Allows EC2 instances to register with ECS and run tasks
resource "aws_iam_role_policy_attachment" "ecs_instance_ecs_policy" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# Allows ECS Managed Instances to communicate with ECS control plane
resource "aws_iam_role_policy_attachment" "ecs_instance_managed_instances_policy" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECSInstanceRolePolicyForManagedInstances"
}

# Instance profile required for ECS Managed Instances
resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${local.name}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name
}
