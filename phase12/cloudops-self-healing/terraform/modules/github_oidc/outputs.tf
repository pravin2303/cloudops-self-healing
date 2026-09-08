output "github_actions_role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes via OIDC. Set this as the AWS_ROLE_ARN repository variable."
  value       = aws_iam_role.github_actions.arn
}
