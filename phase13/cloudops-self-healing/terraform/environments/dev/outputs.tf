output "vpc_id" {
  value = module.networking.vpc_id
}

output "vpc_cidr_block" {
  value = module.networking.vpc_cidr_block
}

output "public_subnet_ids" {
  value = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.networking.private_subnet_ids
}

output "nat_gateway_ids" {
  value = module.networking.nat_gateway_ids
}

output "internet_gateway_id" {
  value = module.networking.internet_gateway_id
}

output "alb_security_group_id" {
  value = module.security.alb_security_group_id
}

output "ec2_security_group_id" {
  value = module.security.ec2_security_group_id
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "ecr_repository_arn" {
  value = module.ecr.repository_arn
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "target_group_arn" {
  value = module.alb.target_group_arn
}

output "launch_template_id" {
  value = module.compute.launch_template_id
}

output "iam_role_arn" {
  value = module.compute.iam_role_arn
}

output "asg_name" {
  value = module.autoscaling.asg_name
}

output "dashboard_name" {
  value = module.monitoring.dashboard_name
}

output "dashboard_url" {
  value = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${module.monitoring.dashboard_name}"
}

output "sns_topic_arn" {
  value = module.monitoring.sns_topic_arn
}

output "log_group_name" {
  value = module.monitoring.log_group_name
}

output "github_actions_role_arn" {
  value = module.github_oidc.github_actions_role_arn
}
