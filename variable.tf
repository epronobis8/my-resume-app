variable "aws_region" {
  type    = string
  default = "us-east-1"
  #prompts user for the region
}

variable "envTag" {
  type    = string
  default = "prod"
}

variable "bucket" {
  type    = string
}