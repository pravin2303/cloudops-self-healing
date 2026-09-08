# ---------------------------------------------------------------------------
# ALB Security Group — public entry point
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for the public Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description        = "Allow HTTP from the internet"
  cidr_ipv4          = "0.0.0.0/0"
  from_port           = 80
  to_port             = 80
  ip_protocol         = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description        = "Allow HTTPS from the internet"
  cidr_ipv4          = "0.0.0.0/0"
  from_port           = 443
  to_port             = 443
  ip_protocol         = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description        = "Allow all outbound so the ALB can reach EC2 targets on the app port"
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol         = "-1"
}

# ---------------------------------------------------------------------------
# EC2 Security Group — application instances
#
# Deliberately has NO SSH ingress rule. Debugging access is via AWS
# Systems Manager Session Manager (configured through the instance's
# IAM role in Phase 7), which requires no inbound port at all — it
# tunnels over the instance's existing outbound connection.
# ---------------------------------------------------------------------------

resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Security group for application EC2 instances"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ec2-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "Allow app traffic only from the ALB security group"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                     = var.app_port
  to_port                       = var.app_port
  ip_protocol                   = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "ec2_all" {
  security_group_id = aws_security_group.ec2.id
  description        = "Allow all outbound (ECR image pulls via NAT, SSM, CloudWatch, package updates)"
  cidr_ipv4          = "0.0.0.0/0"
  ip_protocol         = "-1"
}
