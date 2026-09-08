output "launch_template_id" {
  description = "ID of the Launch Template — the Auto Scaling Group in Phase 8 references this."
  value       = aws_launch_template.app.id
}

output "launch_template_latest_version" {
  description = "Latest version number of the Launch Template."
  value       = aws_launch_template.app.latest_version
}

output "iam_role_arn" {
  description = "ARN of the EC2 instance IAM role."
  value       = aws_iam_role.ec2.arn
}

output "iam_role_name" {
  description = "Name of the EC2 instance IAM role."
  value       = aws_iam_role.ec2.name
}

output "iam_instance_profile_name" {
  description = "Name of the instance profile attached to launched instances."
  value       = aws_iam_instance_profile.ec2.name
}
