output "cfn_arn" {
  value       = aws_cloudfront_distribution.s3_distribution.arn
  description = "Output of the Arn of CF Distribution to leverage as part of a variable for s3 bucket policy"
}