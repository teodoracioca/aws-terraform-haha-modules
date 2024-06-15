terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
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

  egress {
    from_port   = local.any_port
    to_port     = local.any_port
    protocol    = local.any_port
    cidr_blocks = local.all_ips
  }
}

resource "aws_lb" "example" {
  name               = var.alb_name
  load_balancer_type = "application"
  subnets            = var.subnet_ids
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

resource "aws_security_group" "alb" {

  name   = var.alb_name
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

locals {
  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}