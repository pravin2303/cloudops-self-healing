module "networking" {
  source = "../../modules/networking"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
}

module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.networking.vpc_id
  app_port     = var.app_port
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

module "alb" {
  source = "../../modules/alb"

  project_name           = var.project_name
  environment             = var.environment
  vpc_id                  = module.networking.vpc_id
  public_subnet_ids       = module.networking.public_subnet_ids
  alb_security_group_id   = module.security.alb_security_group_id
  app_port                = var.app_port
  health_check_path       = var.health_check_path
}

module "compute" {
  source = "../../modules/compute"

  project_name           = var.project_name
  environment              = var.environment
  aws_region                = var.aws_region
  instance_type              = var.instance_type
  ec2_security_group_id      = module.security.ec2_security_group_id
  ecr_repository_url         = module.ecr.repository_url
  ecr_repository_arn         = module.ecr.repository_arn
  image_tag                  = var.app_image_tag
  app_port                   = var.app_port
}

module "autoscaling" {
  source = "../../modules/autoscaling"

  project_name               = var.project_name
  environment                  = var.environment
  launch_template_id           = module.compute.launch_template_id
  private_subnet_ids           = module.networking.private_subnet_ids
  target_group_arn             = module.alb.target_group_arn
  min_size                     = var.min_size
  desired_capacity              = var.desired_capacity
  max_size                      = var.max_size
  health_check_grace_period     = var.health_check_grace_period
  cpu_target_value              = var.cpu_target_value
}
