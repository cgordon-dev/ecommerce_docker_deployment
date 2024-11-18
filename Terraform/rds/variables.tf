variable "db_instance_class" {
  description = "The instance type of the RDS instance"
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "The name of the database to create when the DB instance is created"
  type        = string
  default     = "ecommerce"
}

variable "db_username" {
  description = "Username for the master DB user"
  type        = string
  default     = "kurac5user"
}

variable "db_password" {
    description = "password for db user"
    type = string
    default = "kurac5password"
}

variable "vpc_id" {
}

variable "private_subnet_id" {
}

variable "private_subnet_id_2" {
}

variable "app_security_group_id" {
}