variable "instance_type" {
  description = "The type of EC2 instance to use"
  type        = string
  default     = "t3.micro"
}

variable "vpc_id" {
}

variable "public_subnet_id_1" {
}

variable "private_subnet_id_1" {
}

variable "public_subnet_id_2" {
}

variable "private_subnet_id_2" {
}

variable "app_security_group_id" {
}

variable "ami" {
  description = "The Amazon Machine Image (AMI) ID used to launch the EC2 instance."
  type = string
  default = "ami-0866a3c8686eaeeba"
}

variable "rds_endpoint" {
}

variable "dockerhub_username" {
  description = "Docker hub username"
  type        = string
}

variable "dockerhub_password" {
  description = "Docker hub password"
  type        = string
  sensitive = true
}