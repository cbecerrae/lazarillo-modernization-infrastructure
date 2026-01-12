variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (stg, prod)"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC (/16)"
  type        = string
}

variable "aws_availability_zones_ids" {
  description = "List of AWS availability zones IDs"
  type        = list(string)
}

variable "single_az" {
  description = "Deploy resources only in the first AZ ID if true, otherwise use all AZ IDs"
  type        = bool
  default     = false
}
