provider "aws" {
  region = "eu-central-1"
}

locals {
 ssh_port = 22
 http_port = 80
 any_port = 0
 any_protocol = "-1"
 tcp_protocol = "tcp"
 all_ips = ["0.0.0.0/0"]
}

# Reference the default VPC
data "aws_vpc" "default" {
  default = true
}

# Reference the existing Internet Gateway
data "aws_internet_gateway" "internet-gw" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_route_table" "rt" {
  vpc_id = data.aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.internet-gw.id
  }
}

resource "aws_route_table_association" "rta" {
  subnet_id      = "subnet-0d36451c51ebbc7bb"
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "sg-nou" {
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "8080 from the Internet"
    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = local.tcp_protocol
    cidr_blocks = local.all_ips
  }

  ingress {
    description = "SSH from the internet"
    from_port   = local.ssh_port
    to_port     = local.ssh_port
    protocol    = local.tcp_protocol
    cidr_blocks = local.all_ips
  }

  egress {
    from_port   = local.any_port
    to_port     = local.any_port
    protocol    = local.any_port
    cidr_blocks = local.all_ips
  }
}

# Reference the default Subnets
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_launch_configuration" "teo-exemplu" {
  image_id        = "ami-026c3177c9bd54288"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.sg-nou.id]
  #  user_data       = <<-EOF
  #                   #!/bin/bash
  #                   echo "<h1>Hello, World from $(hostname -f)</h1>" > index.html
  #                   nohup busybox httpd -f -p ${var.server_port} &
  #                   EOF
  user_data = templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    db_address  = data.terraform_remote_state.db.outputs.address
    db_port     = data.terraform_remote_state.db.outputs.port
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "teo-asg" {
  launch_configuration = aws_launch_configuration.teo-exemplu.name
  vpc_zone_identifier  = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.asg-tg.arn]
  health_check_type = "ELB"

  min_size = var.min_size
  max_size = var.max_size

  tag {
    key                 = "Name"
    value               = "terraform-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "alb" {

  name   = var.cluster_name
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "allow_http_inbound"{
    type = "ingress"
    security_group_id = aws_security_group.alb.id

    from_port   = local.http_port
    to_port     = local.http_port
    protocol    = local.tcp_protocol
    cidr_blocks = local.all_ips

}

resource "aws_security_group_rule" "allow_all_outbound"{
    type = "egress"
    security_group_id = aws_security_group.alb.id

    from_port   = local.any_port
    to_port     = local.any_port
    protocol    = local.any_protocol
    cidr_blocks = local.all_ips

}

resource "aws_lb" "example" {
  name               = var.cluster_name
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = local.http_port
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: Page not found"
      status_code  = "404"
    }
  }
}

resource "aws_lb_target_group" "asg-tg" {
  port     = local.http_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.asg-tg.arn
  }
}

data "terraform_remote_state" "db" {
  backend = "s3"
  config = {
    bucket = var.db_remote_state_bucket
    key    = var.db_remote_state_key
    region = "eu-central-1"
  }
}

