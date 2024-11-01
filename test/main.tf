
provider "aws" {
  #region is set as a variable
  region = var.aws_region
}

locals {
  environment      = "dev"
  app              = "resume-iac-app-dev"
  owner            = "Erin"
  s3_origin_id     = "myS3Origin"
  root_domain_name = "pronobis-aws-examples.com"
  cf_domain_name   = "dev.${local.root_domain_name}"
}


################################################################################
# SSM Parameters
################################################################################

data "aws_ssm_parameter" "cert" {
  name = "/test/resumeapp/certificate"
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
  policy = data.aws_iam_policy_document.my-cdn-cf-policy.json
}

data "aws_iam_policy_document" "my-cdn-cf-policy" {
  statement {
    sid = "1"
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.my_oai.iam_arn]
    }

    actions = [
      "s3:GetObject"
    ]

    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*",
    ]
  }
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
  comment             = "DEV CF Distro for my resume app"
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
    iac         = "true"
    environment = var.envTag
    app         = local.app
  }

  viewer_certificate {
    
    #acm_certificate_arn = var.certarn
    acm_certificate_arn = data.aws_ssm_parameter.cert.value
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
  name         = local.root_domain_name
  private_zone = false
}
