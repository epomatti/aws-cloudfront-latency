output "apprunner_service_url" {
  value = aws_apprunner_service.main.service_url
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.lb_distribution.domain_name
}
