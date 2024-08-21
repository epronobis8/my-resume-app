terraform {
  required_version = ">= 0.15.0"
  backend "s3" {
    bucket         = "terraform-state-bucket-useast1-ep"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock-my-resume-app"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.9.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "3.1.0"
    }
  }
}



