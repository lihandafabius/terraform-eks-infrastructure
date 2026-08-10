variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "private_subnet_cidr_blocks" {
  type    = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidr_blocks" {
  type    = list(string)
  default = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "application_name" {
  type    = string
  default = "java-app"
}

variable "instance_types" {
  type    = list(string)
  default = ["t3.small"]
}

variable "ami_type" {
  type    = string
  default = "AL2023_x86_64_STANDARD"
}

