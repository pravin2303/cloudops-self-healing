resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-${var.environment}-asg"
  min_size             = var.min_size
  desired_capacity     = var.desired_capacity
  max_size             = var.max_size
  vpc_zone_identifier   = values(var.private_subnet_ids)
  target_group_arns    = [var.target_group_arn]

  # ELB health checks — NOT the default EC2Status health check type.
  # This is the critical wiring for self-healing: the ASG asks the ALB
  # "is this instance healthy in your target group?" rather than only
  # "is the underlying EC2 hardware/hypervisor healthy?" An instance
  # can pass EC2 status checks while its application is completely
  # broken; ELB health checks are what catch that and trigger a
  # replacement.
  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period

  launch_template {
    id      = var.launch_template_id
    version = "$Latest"
  }

  # Prefer terminating instances on an older Launch Template version
  # first during any scale-in — naturally cleans up version drift
  # after a deployment.
  termination_policies = ["OldestLaunchTemplate", "Default"]

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-asg-instance"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------
# CPU target-tracking scaling policy.
#
# AWS automatically creates and manages the underlying CloudWatch alarms
# for this policy — we don't hand-write step-scaling alarms for the
# straightforward "keep average CPU near X%" case. Custom alarms for
# operational alerting (not scaling) are added separately in Phase 9.
# ---------------------------------------------------------------------------

resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.project_name}-${var.environment}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type             = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_value
  }
}
