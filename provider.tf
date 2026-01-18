# Define the required Terraform version and providers
terraform {
  required_version = ">= 1.11.4"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.28"
    }
  }

  backend "s3" {
    # bucket       = "lazarillo-modernization-poc-terraform-state"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

# Configure AWS provider
provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "lazarillo-modernization-infrastructure"
      Provider    = "Morris-Opazo"
      Terraform   = "true"
    }
  }
}