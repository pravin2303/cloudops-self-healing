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
