###############################################################################
# modules/alb/main.tf
#
# Internet-facing Application Load Balancer with:
#   * an SG that accepts HTTP/80 from anywhere (CloudFront fronts it in prod)
#   * a target group for HTTP instance targets
#   * a default HTTP listener on port 80
#
# TLS termination happens at CloudFront; adding an HTTPS listener here is a
# one-line extension once a certificate is provisioned in ACM.
###############################################################################

# ---- Security group for the ALB -------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Allow HTTP in from the internet; egress to VPC."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere (fronted by CloudFront)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb-sg" })
}

# ---- Application Load Balancer --------------------------------------------
resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
  idle_timeout               = 60

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb" })
}

# ---- Target group + health check -----------------------------------------
resource "aws_lb_target_group" "web" {
  name        = "${var.name_prefix}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.health_check_path
    matcher             = "200-299"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-tg" })
}

# ---- Default HTTP listener -----------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
