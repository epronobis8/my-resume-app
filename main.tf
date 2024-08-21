
provider "aws" {
  #region is set as a variable
  region = var.aws_region
}


locals {
  owner               = "Erin"
  s3_origin_id = "myS3Origin"
}

################################################################################
# S3 Bucket
################################################################################

resource "aws_s3_bucket" "bucket" {
  bucket = var.bucket

  tags = {
    Environment = var.envTag
    "IAC"       = "true"
  }
}
/*
resource "aws_s3_bucket_acl" "acl" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}
*/
################################################################################
# Cloudfront Distribution
################################################################################

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id                = aws_acm_certificate.cert.domain_name
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

  aliases = ["resume.pronobis-aws-examples.com"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_acm_certificate.cert.domain_name

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cert.arn
    ssl_support_method = "sni-only"
  }
}

resource "aws_cloudfront_origin_access_identity" "my_oai" {
  comment = "CloudFront OAI for S3 bucket"
}

resource "aws_acm_certificate" "cert" {
  domain_name = "resume.pronobis-aws-examples.com"
  validation_method = "EMAIL"

  tags = {
    Environment = var.envTag
  }

  lifecycle {
    create_before_destroy = true
  }
}