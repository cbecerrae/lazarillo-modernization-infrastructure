
resource "aws_security_group" "db" {
  name        = "${local.name}-postgresql-sg"
  description = "PostgreSQL instance security group"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_ingress_sg_ids
    content {
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
      description     = "PostgreSQL ingress"
    }
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
}

resource "aws_instance" "this" {
  ami                    = var.ami
  instance_type          = var.instance_type
  availability_zone      = data.aws_subnet.this.availability_zone
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = var.key_name
  iam_instance_profile   = var.enable_ssm ? aws_iam_instance_profile.ssm[0].name : null
  user_data              = var.user_data

  # Ensure the root EBS volume is encrypted
  root_block_device {
    encrypted = true
  }

  tags = {
    Name = local.name
  }
}

data "aws_subnet" "this" {
  id = var.subnet_id
}

resource "aws_ebs_volume" "this" {
  for_each = var.ebs_volumes

  availability_zone = data.aws_subnet.this.availability_zone
  size              = each.value.volume_size
  type              = "gp3"
  throughput        = each.value.throughput
  iops              = each.value.iops
  encrypted         = true

  tags = {
    Name = "${local.name}-${each.key}"
  }
}

resource "aws_volume_attachment" "this" {
  for_each = var.ebs_volumes

  device_name = each.value.device_name
  volume_id   = aws_ebs_volume.this[each.key].id
  instance_id = aws_instance.this.id
}

