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
  default     = "nominatim-app"
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

variable "db_secret_name" {
  description = "Name of the Secrets Manager secret containing the database credentials"
  type        = string
}

variable "pbf_url" {
  description = "OSM PBF dataset URL"
  type        = string
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
