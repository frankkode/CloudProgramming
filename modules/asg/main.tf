###############################################################################
# modules/asg/main.tf
#
# Web tier (compute):
#   * IAM instance profile with SSM + CloudWatch Agent permissions
#   * Security group only allowing HTTP from the ALB SG
#   * Launch template baking in user-data that installs Apache
#   * Auto Scaling Group across both private application subnets
#   * Two target-tracking scaling policies (CPU and ALB request count)
###############################################################################

# ---- Most recent Amazon Linux 2023 AMI ------------------------------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ---- Instance IAM role + profile ------------------------------------------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.name_prefix}-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = merge(var.tags, { Name = "${var.name_prefix}-ec2-role" })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name_prefix}-ec2-profile"
  role = aws_iam_role.instance.name
}

# ---- Instance security group (only ALB → EC2 :80) -------------------------
resource "aws_security_group" "instance" {
  name        = "${var.name_prefix}-web-sg"
  description = "Allow HTTP from the ALB; all egress."
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-web-sg" })
}

# ---- Launch template ------------------------------------------------------
resource "aws_launch_template" "web" {
  name_prefix            = "${var.name_prefix}-lt-"
  image_id               = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.instance.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.instance.name
  }

  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }

  monitoring {
    enabled = true
  }

  user_data = base64encode(templatefile(
    "${path.module}/user_data.sh.tftpl",
    {
      project     = var.name_prefix
      environment = lookup(var.tags, "Environment", "dev")
    }
  ))

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name_prefix}-web" })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---- Auto Scaling Group ---------------------------------------------------
resource "aws_autoscaling_group" "web" {
  name                      = "${var.name_prefix}-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.private_app_subnet_ids
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name_prefix}-web"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---- Target-tracking scaling policies -------------------------------------
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.name_prefix}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target
  }
}

resource "aws_autoscaling_policy" "request_count_target" {
  name                   = "${var.name_prefix}-req-count-target"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = replace(var.target_group_arn, "/^.*:loadbalancer\\//", "")
    }
    target_value = var.request_count_target
  }
}
