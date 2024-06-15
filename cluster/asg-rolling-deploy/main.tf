terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
resource "aws_launch_configuration" "example" {
  image_id        = var.ami          #  "ami-026c3177c9bd54288"
  instance_type   = var.instance_type
  security_groups = [aws_security_group.alb.id]
  user_data = var.user_data

  lifecycle {
    create_before_destroy = true
    precondition {
      condition     = data.aws_ec2_instance_type.instance.free_tier_eligible
      error_message = "${var.instance_type} is not part of the AWS Free Tier!"
    }
  }
}

resource "aws_autoscaling_group" "example" {
  name = var.cluster_name

  launch_configuration = aws_launch_configuration.example.name
  vpc_zone_identifier  = var.subnet_ids

  target_group_arns    = var.target_group_arns
  health_check_type    = var.health_check_type

  min_size = var.min_size
  max_size = var.max_size

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  tag {
    key                 = "Name"
    value               = var.cluster_name
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = {
      for key, value in var.custom_tags:
      key => upper(value)
      if key != "Name"
    }

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    postcondition {
      condition     = length(self.availability_zones) > 1
      error_message = "You must use more than one AZ for high availability!"
    }
  }
}

# resource "aws_autoscaling_schedule" "scale_out_during_business_hours" {
#   count = var.enable_autoscaling ? 1 : 0

#   scheduled_action_name  = "${var.cluster_name}-scale-out-during-business-hours"
#   min_size               = 2
#   max_size               = 10
#   desired_capacity       = 10
#   recurrence             = "0 9 * * *"
#   autoscaling_group_name = aws_autoscaling_group.example.name
# }

# resource "aws_autoscaling_schedule" "scale_in_at_night" {
#   count = var.enable_autoscaling ? 1 : 0

#   scheduled_action_name  = "${var.cluster_name}-scale-in-at-night"
#   min_size               = 2
#   max_size               = 10
#   desired_capacity       = 2
#   recurrence             = "0 17 * * *"
#   autoscaling_group_name = aws_autoscaling_group.example.name
# }

resource "aws_security_group" "alb" {

  name   = "${var.cluster_name}-alb"
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group_rule" "allow_http_inbound"{
    type = "ingress"
    security_group_id = aws_security_group.alb.id

    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = local.tcp_protocol
    cidr_blocks = local.all_ips

}

data "aws_vpc" "default" {
    default = true
}

data "aws_ec2_instance_type" "instance" {
  instance_type = var.instance_type
}

locals {
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
}