terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.73.0"
    }
  }
}

provider "aws" {
  region     = var.region
}

module "VPC" {
  source = "./modules/vpc"
}

module "RDS" {
  source = "./modules/rds"
  vpc_id = module.VPC.vpc_id
  private_subnet_id = module.VPC.private_subnet_id_1
  private_subnet_id_2 = module.VPC.private_subnet_id_2
  app_security_group_id = module.VPC.app_security_group_id
  depends_on = [module.VPC]
}

module "EC2" {
  source = "./modules/ec2"
  vpc_id = module.VPC.vpc_id
  public_subnet_id_1 = module.VPC.public_subnet_id_1
  public_subnet_id_2 = module.VPC.public_subnet_id_2
  private_subnet_id_1 = module.VPC.private_subnet_id_1
  private_subnet_id_2 = module.VPC.private_subnet_id_2
  app_security_group_id = module.VPC.app_security_group_id
  rds_endpoint = module.RDS.rds_endpoint
  dockerhub_username = var.dockerhub_username
  dockerhub_password = var.dockerhub_password
  depends_on = [module.RDS]
}

module "Load" {
  source = "./modules/load"
  vpc_id = module.VPC.vpc_id
  public_subnet_id_1 =  module.VPC.public_subnet_id_1
  public_subnet_id_2 =  module.VPC.public_subnet_id_2
  instance_id_1 = module.EC2.instance_id_1
  instance_id_2 = module.EC2.instance_id_2
  depends_on = [module.EC2]
}