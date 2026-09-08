output "alb_arn" {
  description = "ARN of the ALB."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "Public DNS name of the ALB — this is what you curl."
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "Route53 hosted zone ID of the ALB (needed if you later add a custom domain alias record)."
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group — the Auto Scaling Group in Phase 8 registers instances here."
  value       = aws_lb_target_group.app.arn
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener."
  value       = aws_lb_listener.http.arn
}

output "alb_arn_suffix" {
  description = "Short ARN suffix used as a CloudWatch metric dimension (e.g. app/name/id)."
  value       = aws_lb.this.arn_suffix
}

output "target_group_arn_suffix" {
  description = "Short ARN suffix used as a CloudWatch metric dimension (e.g. targetgroup/name/id)."
  value       = aws_lb_target_group.app.arn_suffix
}
