variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "envTag" {
  type    = string
  default = "test"
}


variable "bucket" {
  type = string
  default = "test-my-resume-app-bucket-cfint-emp"
}


variable "domain" {
  type    = string
  default = "pronobis-aws-examples.com"
}

