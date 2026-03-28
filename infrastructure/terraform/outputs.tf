# infrastructure/terraform/outputs.tf

output "backend_public_ip" {
  description = "EC2 backend server public IP"
  value       = aws_eip.backend.public_ip
}

output "cloudfront_domain" {
  description = "CloudFront distribution domain name (use this as your API URL)"
  value       = aws_cloudfront_distribution.api.domain_name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.address
  sensitive   = true
}

output "ecr_backend_url" {
  description = "ECR repository URL for backend image"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_ai_url" {
  description = "ECR repository URL for AI engine image"
  value       = aws_ecr_repository.ai_engine.repository_url
}

output "s3_bucket" {
  description = "S3 bucket name for assets"
  value       = aws_s3_bucket.assets.bucket
}

output "lambda_function_name" {
  description = "Lambda function name for AI predictions"
  value       = aws_lambda_function.ai_predict.function_name
}

output "api_url" {
  description = "Production API base URL"
  value       = "https://${aws_cloudfront_distribution.api.domain_name}/api/v1"
}

output "ssh_command" {
  description = "SSH command to connect to backend server"
  value       = "ssh -i ~/.ssh/flowpath.pem ubuntu@${aws_eip.backend.public_ip}"
}
