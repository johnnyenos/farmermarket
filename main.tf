provider "aws" {
  region = "us-east-1"
}

# S3 Bucket for Hosting Static Website
resource "aws_s3_bucket" "farmers_market_bucket" {
  bucket = "farmers-market-platform-bucket"
}

# S3 Bucket Public Access Block Configuration (to allow public access)
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket = aws_s3_bucket.farmers_market_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# S3 Bucket Policy to Allow Public Read Access
resource "aws_s3_bucket_policy" "public_access" {
  bucket = aws_s3_bucket.farmers_market_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = "*",
        Action = "s3:GetObject",
        Resource = "${aws_s3_bucket.farmers_market_bucket.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.public_access_block]
}

# S3 Bucket Website Configuration (Separate Resource)
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.farmers_market_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }

  depends_on = [aws_s3_bucket.farmers_market_bucket]
}

# Upload index.html to S3 (without ACL)
resource "aws_s3_object" "index" {
  bucket = aws_s3_bucket.farmers_market_bucket.bucket
  key    = "index.html"
  source = "index.html"  # Files are in the same directory as main.tf
  content_type = "text/html"

  depends_on = [aws_s3_bucket_website_configuration.website_config]
}

# Upload error.html to S3 (without ACL)
resource "aws_s3_object" "error" {
  bucket = aws_s3_bucket.farmers_market_bucket.bucket
  key    = "error.html"
  source = "error.html"  # Files are in the same directory as main.tf
  content_type = "text/html"

  depends_on = [aws_s3_bucket_website_configuration.website_config]
}

# CloudFront Origin Access Identity
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Access to S3 bucket for CloudFront"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "farmers_market_distribution" {
  origin {
    domain_name = aws_s3_bucket.farmers_market_bucket.bucket_regional_domain_name
    origin_id   = "S3-origin"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-origin"

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

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    minimum_protocol_version        = "TLSv1.2_2018"
  }

  depends_on = [
    aws_s3_bucket.farmers_market_bucket,
    aws_cloudfront_origin_access_identity.origin_access_identity
  ]
}

# Outputs
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.farmers_market_distribution.domain_name
}

output "s3_website_url" {
  value = "http://${aws_s3_bucket.farmers_market_bucket.bucket}.s3-website-${aws_s3_bucket.farmers_market_bucket.region}.amazonaws.com"
}
