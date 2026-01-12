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
  default     = "wordpress"
}

variable "vpc_id" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "db_name" {
  type    = string
  default = "wordpress"
}

variable "container_cpu" {
  type    = number
}

variable "container_memory" {
  type    = number
}

locals {
  name = "${var.project_name}-${var.environment}-${var.subproject_name}"
}
