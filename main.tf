
provider "aws" {
  #region is set as a variable
  region = var.aws_region
}

locals {
  environment      = "prod"
  app              = "resume-iac-app"
  owner            = "Erin"
  s3_origin_id     = "myS3Origin"
  root_domain_name = "pronobis-aws-examples.com"
  cf_domain_name   = "resume.${local.root_domain_name}"
  bucket_policy = var.bucket_policy != "" ? var.bucket_policy : jsonencode(
    {
      "Version" : "2008-10-17",
      "Id" : "PolicyForCloudFrontPrivateContent",
      "Statement" : [
        {
          "Sid" : "AllowCloudFrontServicePrincipal",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "cloudfront.amazonaws.com"
          },
          "Action" : "s3:GetObject",
          "Resource" : "arn:aws:s3:::${var.bucket}/*",
          "Condition" : {
            "StringEquals" : {
              "AWS:SourceArn" : "${var.arn}"
            }
          }
        }
      ]
    }
  )
}

################################################################################
# S3 Bucket
################################################################################

resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket

  tags = {
    iac         = "true"
    environment = var.envTag
    app         = local.app
  }
}

resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = local.bucket_policy
}
################################################################################
# Cloudfront Distribution
################################################################################

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.my_oai.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CF Distrobution for my resume app"
  default_root_object = "index.html"

  /*
  logging_config {
    include_cookies = false
    bucket          = "cloudfront-resume-app-logs.s3.amazonaws.com"
    prefix          = "myprefix"
  }
  */

  aliases = [local.cf_domain_name]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_All"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "prod"

  }

  viewer_certificate {
    acm_certificate_arn = var.certarn
    ssl_support_method  = "sni-only"
  }
}

resource "aws_cloudfront_origin_access_identity" "my_oai" {
  comment = "CloudFront OAI for S3 bucket"
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = local.cf_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}
data "aws_route53_zone" "zone" {
  name = local.root_domain_name
  private_zone = false 
}
