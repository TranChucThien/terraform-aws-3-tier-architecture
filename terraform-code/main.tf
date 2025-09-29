variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-2"

}

variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "three-tier-architecture"

}

provider "aws" {
  region = "us-east-2"

}



terraform {
  backend "s3" {
    bucket       = "tct-three-tier-app"
    key          = "global/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true
    encrypt      = true
  }
}

module "vpc" {
  source                   = "./modules/vpc"
  name                     = "${var.project_name}-vpc"
  azs                      = ["us-east-2a", "us-east-2b"]
  public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_app_cidrs = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnet_db_cidrs  = ["10.0.201.0/24", "10.0.202.0/24", ]
}

module "sg_presentation" {
  source  = "./modules/securitygroup"
  vpc_id  = module.vpc.vpc_id
  sg_name = "${var.project_name}-sg-presentation"
  ingress_rules = [
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },   # SSH
    { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },   # HTTP
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }, # HTTPS
    { from_port = 27017, to_port = 27017, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }, # MongoDB
    { from_port = 8000, to_port = 8000, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }, # Backend
    { from_port = 3000, to_port = 3000, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }, # Frontend
  ]

}

module "sg_app" {
  source  = "./modules/securitygroup"
  vpc_id  = module.vpc.vpc_id
  sg_name = "${var.project_name}-sg-app"
  ingress_rules = [
    { from_port = 8080, to_port = 8080, protocol = "tcp", security_groups = [module.sg_presentation.security_group_id] }, # PostgreSQL
    { from_port = 22, to_port = 22, protocol = "tcp", security_groups = [module.sg_presentation.security_group_id] },     # SSH
    # { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },   # HTTP
    # { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }, # HTTPS
  ]

}

module "sg_db" {
  source  = "./modules/securitygroup"
  vpc_id  = module.vpc.vpc_id
  sg_name = "${var.project_name}-sg-db"
  ingress_rules = [
    { from_port = 5432, to_port = 5432, protocol = "tcp", security_groups = [module.sg_app.security_group_id] }, # PostgreSQL
    { from_port = 22, to_port = 22, protocol = "tcp", security_groups = [module.sg_app.security_group_id] },     # HTTP
    # { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }, # HTTPS
  ]

}

module "ec2_presentation" {
  count              = 1
  source             = "./modules/ec2/ec2"
  instance_ami       = "ami-0ca4d5db4872d0c28" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type      = "t2.micro"
  key_name           = "tct-key-pair"
  ec2_name           = "Presentation-EC2"
  subnet_id          = module.vpc.public_subnet_ids[0]
  security_group_ids = [module.sg_presentation.security_group_id]
  user_data          = var.user_data_db

}

module "ec2_presentation_be" {
  count              = 1
  source             = "./modules/ec2/ec2"
  instance_ami       = "ami-0ca4d5db4872d0c28" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type      = "t2.micro"
  key_name           = "tct-key-pair"
  ec2_name           = "Presentation-EC2-BE"
  subnet_id          = module.vpc.public_subnet_ids[0]
  security_group_ids = [module.sg_presentation.security_group_id]
  user_data          = var.user_data_be

}

module "ec2_presentation_fe" {
  count              = 1
  source             = "./modules/ec2/ec2"
  instance_ami       = "ami-0ca4d5db4872d0c28" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type      = "t2.micro"
  key_name           = "tct-key-pair"
  ec2_name           = "Presentation-EC2-FE"
  subnet_id          = module.vpc.public_subnet_ids[0]
  security_group_ids = [module.sg_presentation.security_group_id]
  user_data          = var.user_data_fe

}

module "ec2_app" {
  count = 0
  source             = "./modules/ec2/ec2"
  instance_ami       = "ami-0ca4d5db4872d0c28" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type      = "t2.micro"
  key_name           = "tct-key-pair"
  ec2_name           = "App-EC2"
  subnet_id          = module.vpc.private_subnet_app_ids[0]
  security_group_ids = [module.sg_app.security_group_id]

}

module "ec2_db" {
  count = 0
  source             = "./modules/ec2/ec2"
  instance_ami       = "ami-0ca4d5db4872d0c28" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type      = "t2.micro"
  key_name           = "tct-key-pair"
  ec2_name           = "DB-EC2"
  subnet_id          = module.vpc.private_subnet_db_ids[0]
  security_group_ids = [module.sg_db.security_group_id]
  
}