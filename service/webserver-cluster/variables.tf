variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8080
}

variable "instance_type" {
  description = "The type of the EC2 instance"
  type = string
}

variable "min_size" {
  description = "The minimum number of the EC2 instances in the ASG"
  type = number
}

variable "max_size" {
  description = "The maximum number of the EC2 instances in the ASG"
  type = number
}

variable "alb_sg_name" {
  description = "The name of the SG-ALB"
  type        = string
  default     = "alb-sg"
}

variable "cluster_name" {
 description = "The name to use for all the cluster resources"
 type = string
}

variable "db_remote_state_bucket" {
 description = "The name of the S3 bucket for the database's remote state"
 type = string
}

variable "db_remote_state_key" {
 description = "The path for the database's remote state in S3"
 type = string
}