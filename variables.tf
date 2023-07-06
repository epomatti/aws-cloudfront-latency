variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "ecr_image" {
  type = string
}

variable "port" {
  type    = string
  default = "8080"
}
