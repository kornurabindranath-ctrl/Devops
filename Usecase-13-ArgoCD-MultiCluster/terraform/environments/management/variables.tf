
variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "owner" {
  type = string
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
}
variable "availability_zones" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}
variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
}
