variable "aws_region" {
  type    = string
  default = "us-east-1"
  #prompts user for the region
}

variable "dynamodb-name" {
  type    = string
  default = "my-resume-app-db"
  #If you change the name of the dynamodb table it will need to be updated in the lambda_function.py file (line 9)
}

variable "envTag" {
  type    = string
  default = "prod"
}

variable "api-name" {
  type    = string
  default = "rest-api-my-resume-app"
}
variable "stage-name" {
  type    = string
  default = "prod"
}

variable "bucket" {
  type    = string
}