# Create bastion hosts  
resource "aws_instance" "ecommerce_bastion_az1"{
  ami               = var.ami                                                                          
  instance_type     = var.instance_type
  # Attach an existing security group to the instance.
  vpc_security_group_ids = [aws_security_group.bastion_security_group.id]
  key_name          = "workload6-key" # The key pair name for SSH access to the instance.
  subnet_id         = var.public_subnet_id_1
  user_data         = <<-EOF
    #!/bin/bash
    # Redirect stdout and stderr to a log file
    exec > /var/log/user-data.log 2>&1
    echo "${file("./public_key.txt")}" >> /home/ubuntu/.ssh/authorized_keys
  EOF
  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "ecommerce_bastion_az1"         
  }

}

resource "aws_instance" "ecommerce_bastion_az2"{
  ami               = var.ami                                                                          
  instance_type     = var.instance_type
  # Attach an existing security group to the instance.
  vpc_security_group_ids = [aws_security_group.bastion_security_group.id]
  key_name          = "workload6-key" # The key pair name for SSH access to the instance.
  subnet_id         = var.public_subnet_id_2
  user_data         = <<-EOF
    #!/bin/bash
    # Redirect stdout and stderr to a log file
    exec > /var/log/user-data.log 2>&1
    echo "${file("./public_key.txt")}" >> /home/ubuntu/.ssh/authorized_keys
  EOF
  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "ecommerce_bastion_az2"         
  }

}

# Security Group for the bastion host
resource "aws_security_group" "bastion_security_group" {
  name        = "bastion_sg"
  description = "Security group for jumpbox"
  vpc_id = var.vpc_id

  # Ingress (inbound) rules
  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from any IP
  }

  # Ingress (inbound) rules
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow SSH from any IP
  }

  # Egress (outbound) rule to allow all traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allow all outbound traffic
  }

  tags = {
    Name : "bastion_sg"
    Terraform : "true"
  }
}

# Create app instances in AWS. 
resource "aws_instance" "ecommerce_app_az1"{
  ami               = var.ami                                                                          
  instance_type     = var.instance_type
  # Attach an existing security group to the instance.
  vpc_security_group_ids = [var.app_security_group_id]
  key_name          = "workload6-key" # The key pair name for SSH access to the instance.
  subnet_id         = var.private_subnet_id_1
  user_data         = base64encode(templatefile("./deploy.sh", {
    rds_endpoint = var.rds_endpoint,
    docker_user = var.dockerhub_username,
    docker_pass = var.dockerhub_password,
    docker_compose = templatefile("./compose.yml", {
      rds_endpoint = var.rds_endpoint,
      run_migrations = "true"
    })
  }))
  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "ecommerce_app_az1"         
  }
}

resource "aws_instance" "ecommerce_app_az2"{
  ami               = var.ami                                                                          
  instance_type     = var.instance_type
  # Attach an existing security group to the instance.
  vpc_security_group_ids = [var.app_security_group_id]
  key_name          = "workload6-key" # The key pair name for SSH access to the instance.
  subnet_id         = var.private_subnet_id_2
  user_data         = base64encode(templatefile("./deploy.sh", {
    rds_endpoint = var.rds_endpoint,
    docker_user = var.dockerhub_username,
    docker_pass = var.dockerhub_password,
    docker_compose = templatefile("./compose.yml", {
      rds_endpoint = var.rds_endpoint,
      run_migrations = "false"
    })
  }))

  # Tagging the resource with a Name label. Tags help in identifying and organizing resources in AWS.
  tags = {
    "Name" : "ecommerce_app_az2"         
  }
}