terraform {
  required_version = "~> 1.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.97.0"
    }

    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.39.0"
    }
  }

}

provider "aws" {
  region = "eu-west-1"
}

