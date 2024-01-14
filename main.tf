terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.32.1"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

### App Runner ###
resource "aws_apprunner_service" "main" {
  service_name = "service-latency-test"

  instance_configuration {
    cpu               = "1 vCPU"
    memory            = "2 GB"
    instance_role_arn = aws_iam_role.instance_role.arn
  }

  source_configuration {
    auto_deployments_enabled = false

    image_repository {
      image_configuration {
        port = var.port
      }
      image_identifier      = var.ecr_image
      image_repository_type = "ECR"
    }

    authentication_configuration {
      access_role_arn = aws_iam_role.access_role.arn
    }
  }
}

resource "aws_iam_role" "instance_role" {
  name = "StressboxInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "tasks.apprunner.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "access_role" {
  name = "StressboxAccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "build.apprunner.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "access_role" {
  role       = aws_iam_role.access_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

### CloudFront ###
resource "aws_cloudfront_distribution" "lb_distribution" {
  enabled         = true
  is_ipv6_enabled = true
  price_class     = "PriceClass_All"
  http_version    = "http2and3"

  origin {
    domain_name = aws_apprunner_service.main.service_url
    origin_id   = aws_apprunner_service.main.service_url

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    cache_policy_id  = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    allowed_methods  = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods   = ["HEAD", "GET"]
    target_origin_id = aws_apprunner_service.main.service_url
    compress         = true

    # forwarded_values {
    #   query_string = true
    #   headers      = ["Origin", "Authorization", "Host"]
    #   cookies {
    #     forward = "all"
    #   }
    # }

    viewer_protocol_policy = "redirect-to-https"
  }

  restrictions {
    geo_restriction {
      locations        = []
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    # minimum_protocol_version       = "TLSv1.2_2021"
    minimum_protocol_version = "TLSv1"
  }
}
