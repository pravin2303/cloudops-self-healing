# ---------------------------------------------------------------------------
# AMI lookup — always resolves to the latest Amazon Linux 2023 image at
# plan time, rather than hardcoding an AMI ID that goes stale and
# eventually gets deprecated by AWS.
# ---------------------------------------------------------------------------

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------------------------------------------------------------------------
# IAM Role — assumed by EC2 instances only. No human or other service
# can assume this role.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "${var.project_name}-${var.environment}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ec2-role"
  })
}

# Least-privilege ECR pull policy, scoped to exactly this repository.
# ecr:GetAuthorizationToken is an account-level, non-resource-scoped
# action required by the ECR API itself — it cannot be restricted to a
# single repository ARN, but everything else here is repo-scoped.
data "aws_iam_policy_document" "ecr_pull" {
  statement {
    sid       = "ECRAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ECRPullFromThisRepoOnly"
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [var.ecr_repository_arn]
  }
}

resource "aws_iam_role_policy" "ecr_pull" {
  name   = "${var.project_name}-${var.environment}-ecr-pull"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ecr_pull.json
}

# Enables AWS Systems Manager Session Manager — our SSH replacement.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Enables the CloudWatch agent to push custom metrics/logs — actually
# configured and used starting Phase 9, but the permission needs to
# exist on the role from the start since it's baked into every
# instance the ASG ever launches.
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ---------------------------------------------------------------------------
# Launch Template
# ---------------------------------------------------------------------------

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-${var.environment}-lt-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  vpc_security_group_ids = [var.ec2_security_group_id]

  # Enforce IMDSv2 — see rationale in the phase documentation.
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    http_endpoint                = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.root_volume_size_gb
      volume_type            = "gp3"
      encrypted               = true
      delete_on_termination   = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tpl", {
    aws_region         = var.aws_region
    ecr_registry       = split("/", var.ecr_repository_url)[0]
    ecr_repository_url = var.ecr_repository_url
    image_tag           = var.image_tag
    app_port             = var.app_port
    log_group_name       = var.log_group_name
  }))

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.tags, {
      Name = "${var.project_name}-${var.environment}-instance"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-lt"
  })

  # Ensures a new Launch Template version is created before any
  # reference to the old default is removed, avoiding a gap during
  # updates (e.g. when Phase 12's CI/CD bumps image_tag).
  lifecycle {
    create_before_destroy = true
  }
}
