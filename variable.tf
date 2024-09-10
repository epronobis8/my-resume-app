variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "envTag" {
  type    = string
  default = "prod"
}

variable "bucket" {
  type = string
}

variable "certarn" {
  type    = string
}

variable "domain" {
  type    = string
  default = "pronobis-aws-examples.com"
}
variable "bucket_policy" {
  type        = string
  default     = ""
  description = "bucket policy for s3 bucket"
}


variable "arn" {
  type        = string
  description = "ARN for CF distribution"
}
