# Security group for the Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb-sg"
  vpc_id      = var.vpc_id
  description = "Security group for Application Load Balancer"
}

# Security group rule to allow HTTP access from the internet
resource "aws_security_group_rule" "alb_ingress_internet" {
  security_group_id = aws_security_group.alb.id
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow HTTP access from the internet"
}

# Security group rule to allow traffic to ECS tasks
resource "aws_security_group_rule" "alb_egress_ecs" {
  security_group_id        = aws_security_group.alb.id
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "Allow HTTP traffic to ECS tasks"
}

# Application Load Balancer
resource "aws_lb" "this" {
  name               = "${local.name}-alb"
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [aws_security_group.alb.id]
}

# Target group for ECS service
resource "aws_lb_target_group" "this" {
  name        = "${local.name}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/status.php"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

# HTTP listener for the ALB
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
