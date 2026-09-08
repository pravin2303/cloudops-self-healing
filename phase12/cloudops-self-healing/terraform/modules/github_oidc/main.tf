# ---------------------------------------------------------------------------
# GitHub's OIDC provider — one per AWS account, shared across every
# repository/project that uses GitHub Actions OIDC in this account.
# ---------------------------------------------------------------------------

data "tls_certificate" "github" {
  count = var.create_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com/.well-known/openid-configuration"
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github[0].certificates[0].sha1_fingerprint]

  tags = var.tags
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn
}

# ---------------------------------------------------------------------------
# IAM Role assumable ONLY by GitHub Actions workflows running on the
# specified branch of the specified repository.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:${var.allowed_ref}"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                 = "${var.project_name}-${var.environment}-github-actions-role"
  assume_role_policy    = data.aws_iam_policy_document.github_assume_role.json
  max_session_duration  = 3600 # 1 hour — plenty for a CI job, nothing long-lived

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-github-actions-role"
  })
}

# ---------------------------------------------------------------------------
# Permissions: push access to exactly this ECR repository. Nothing else.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecr_push" {
  statement {
    sid       = "ECRAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ECRPushToThisRepoOnly"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [var.ecr_repository_arn]
  }
}

resource "aws_iam_role_policy" "ecr_push" {
  name   = "${var.project_name}-${var.environment}-github-ecr-push"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.ecr_push.json
}

# ---------------------------------------------------------------------------
# Deploy permissions: create/modify only this specific Launch Template,
# and start Instance Refreshes only on this specific ASG. Some EC2/ASG
# Describe* actions don't support resource-level scoping at all (AWS
# API limitation, not a choice made here) — those are necessarily "*";
# every mutating action is scoped to the exact resource ARN.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "EC2LaunchTemplateDescribe"
    actions   = ["ec2:DescribeLaunchTemplates", "ec2:DescribeLaunchTemplateVersions"]
    resources = ["*"]
  }

  statement {
    sid       = "EC2LaunchTemplateWrite"
    actions   = ["ec2:CreateLaunchTemplateVersion", "ec2:ModifyLaunchTemplate"]
    resources = [var.launch_template_arn]
  }

  statement {
    sid       = "ASGDescribe"
    actions   = ["autoscaling:DescribeAutoScalingGroups", "autoscaling:DescribeInstanceRefreshes"]
    resources = ["*"]
  }

  statement {
    sid       = "ASGInstanceRefresh"
    actions   = ["autoscaling:StartInstanceRefresh"]
    resources = [var.asg_arn]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "${var.project_name}-${var.environment}-github-deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.deploy.json
}
