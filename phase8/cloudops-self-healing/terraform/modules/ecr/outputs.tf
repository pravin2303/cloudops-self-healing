output "repository_url" {
  description = "Full URI used for docker push/pull (e.g. <account>.dkr.ecr.<region>.amazonaws.com/name)."
  value       = aws_ecr_repository.app.repository_url
}

output "repository_arn" {
  description = "ARN of the ECR repository (needed for IAM policies in Phase 7)."
  value       = aws_ecr_repository.app.arn
}

output "repository_name" {
  description = "Name of the ECR repository."
  value       = aws_ecr_repository.app.name
}
