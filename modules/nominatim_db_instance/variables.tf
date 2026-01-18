variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (stg, prod)"
  type        = string
}

variable "subproject_name" {
  description = "Subproject name"
  type        = string
  default     = "nominatim-postgresql"
}

variable "vpc_id" {
  description = "VPC where the instance will live"
  type        = string
}

variable "subnet_id" {
  description = "Subnet for the instance"
  type        = string
}

variable "allowed_ingress_sg_ids" {
  description = "Security group IDs allowed to reach PostgreSQL"
  type        = list(string)
  default     = []
}

variable "ami" {
  description = "AMI for the PostgreSQL host"
  type        = string
}

variable "instance_type" {
  description = "Instance type for PostgreSQL"
  type        = string
}

variable "ebs_volumes" {
  description = "Map of EBS volumes to attach"
  type = map(object({
    volume_size = number
    throughput  = number
    iops        = number
    device_name = string
  }))
  default = {
    pgdata = {
      volume_size = 1000
      throughput  = 500
      iops        = 8000
      device_name = "/dev/sdd"
    }
    pgwal = {
      volume_size = 150
      throughput  = 350
      iops        = 7000
      device_name = "/dev/sde"
    }
    mnt = {
      volume_size = 300
      throughput  = 512
      iops        = 5000
      device_name = "/dev/sdg"
    }
  }
}

variable "enable_ssm" {
  description = "Create SSM instance role/profile"
  type        = bool
  default     = false
}

variable "key_name" {
  description = "Optional EC2 key pair"
  type        = string
  default     = null
}

variable "user_data" {
  description = "Optional user data script for PostgreSQL setup"
  type        = string
  default     = null
}

locals {
  name = "${var.project_name}-${var.environment}-${var.subproject_name}"
}
