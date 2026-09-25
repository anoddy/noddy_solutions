###############################################################################
# Terraform & provider version constraints
###############################################################################
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Recommended for teams: store state remotely with locking.
  # backend "s3" {
  #   bucket       = "my-terraform-state-bucket"
  #   key          = "nimbus-landing/terraform.tfstate"
  #   region       = "eu-central-1"
  #   use_lockfile = true
  #   encrypt      = true
  # }
}
