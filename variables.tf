variable "project_name" {
  description = "Project name"
  type        = string
  default     = "lazarillo"
}

variable "environment" {
  description = "Environment name (stg, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC (/16)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aws_availability_zones_ids" {
  description = "List of AWS availability zones IDs"
  type        = list(string)
  default     = ["use1-az1", "use1-az2", "use1-az4"]
}