output "asg_name" {
  description = "Name of the Auto Scaling Group."
  value       = aws_autoscaling_group.app.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group."
  value       = aws_autoscaling_group.app.arn
}

output "scaling_policy_arn" {
  description = "ARN of the CPU target-tracking scaling policy."
  value       = aws_autoscaling_policy.cpu_target_tracking.arn
}
