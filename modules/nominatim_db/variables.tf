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
  type = string
}

variable "private_subnets" {
  type = list(string)
}

variable "container_cpu" {
  type    = number
}

variable "container_memory" {
  type    = number
}

variable "nominatim_ecs_tasks_sg_id" {
  description = "Security group ID of the Nominatim ECS tasks"
  type        = string
}

variable "db_secret_name" {
  description = "Name of the Secrets Manager secret containing the database credentials"
  type        = string
}

locals {
  name = "${var.project_name}-${var.environment}-${var.subproject_name}"
}
