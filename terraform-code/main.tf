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
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["14.161.19.182/32"] }, # SSH
    { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },        # HTTP
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },      # HTTPS
    # { from_port = 27017, to_port = 27017, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }, # MongoDB
    { from_port = 8000, to_port = 8000, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }, # Backend
    { from_port = 3000, to_port = 3000, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }, # Frontend
    { from_port = -1, to_port = -1, protocol = "icmp", cidr_blocks = ["0.0.0.0/0"] },    # ICMP
  ]

}

module "sg_app" {
  source  = "./modules/securitygroup"
  vpc_id  = module.vpc.vpc_id
  sg_name = "${var.project_name}-sg-app"
  ingress_rules = [
    { from_port = 8080, to_port = 8080, protocol = "tcp", security_groups = [module.sg_presentation.security_group_id] },
    { from_port = 22, to_port = 22, protocol = "tcp", security_groups = [module.sg_presentation.security_group_id] },     # SSH
    { from_port = 8000, to_port = 8000, protocol = "tcp", security_groups = [module.sg_presentation.security_group_id] }, # Backend
    { from_port = 3000, to_port = 3000, protocol = "tcp", security_groups = [module.sg_presentation.security_group_id] },
  ]

}

module "sg_db" {
  source  = "./modules/securitygroup"
  vpc_id  = module.vpc.vpc_id
  sg_name = "${var.project_name}-sg-db"
  ingress_rules = [
    { from_port = 27017, to_port = 27017, protocol = "tcp", security_groups = [module.sg_app.security_group_id] }, # MongoDB
    { from_port = 22, to_port = 22, protocol = "tcp", security_groups = [module.sg_app.security_group_id] },       # HTTP
    # { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] }, # HTTPS
  ]

}

module "ec2_db" {

  source             = "./modules/ec2/ec2"
  instance_ami       = "ami-0ca4d5db4872d0c28" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type      = "t2.micro"
  key_name           = "tct-key-pair"
  ec2_name           = "Private-EC2-DB"
  subnet_id          = module.vpc.private_subnet_db_ids[0]
  security_group_ids = [module.sg_db.security_group_id]
  user_data          = var.user_data_db

}

# module "ec2_be" {

#   source             = "./modules/ec2/ec2"
#   instance_ami       = "ami-0ca4d5db4872d0c28" # Amazon Linux 2 AMI (HVM), SSD Volume Type
#   instance_type      = "t2.micro"
#   key_name           = "tct-key-pair"
#   ec2_name           = "Private-EC2-BE"
#   subnet_id          = module.vpc.private_subnet_app_ids[0]
#   security_group_ids = [module.sg_app.security_group_id]
#   user_data          = templatefile("templates/user_data_be.sh", { db_private_ip = module.ec2_db.private_ip })
# }

# module "ec2_fe" {
#   count = 0
#   source             = "./modules/ec2/ec2"
#   instance_ami       = "ami-0ca4d5db4872d0c28" # Amazon Linux 2 AMI (HVM), SSD Volume Type
#   instance_type      = "t2.micro"
#   key_name           = "tct-key-pair"
#   ec2_name           = "Private-EC2-FE"
#   subnet_id          = module.vpc.private_subnet_app_ids[1]
#   security_group_ids = [module.sg_app.security_group_id]
#   # user_data          = templatefile("templates/user_data_fe.sh", { be_private_ip = module.ec2_be.private_ip })
#   user_data = templatefile("templates/user_data_fe.sh", { be_private_ip = module.load_balancer.alb_dns_name })
# }

module "ec2_bastion_host" {

  source             = "./modules/ec2/ec2"
  instance_ami       = "ami-0ca4d5db4872d0c28" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type      = "t2.micro"
  key_name           = "tct-key-pair"
  ec2_name           = "Public-EC2-Bastion-Host"
  subnet_id          = module.vpc.public_subnet_ids[0]
  security_group_ids = [module.sg_presentation.security_group_id]
  # user_data          = templatefile("templates/user_data_fe.sh", { be_private_ip = module.ec2_be.private_ip })
  # user_data          = templatefile("templates/user_data_fe.sh", { be_private_ip = module.load_balancer.alb_dns_name })
}

module "target_group_backend" {
  source                = "./modules/target_group"
  target_group_name     = "backend-tg"
  target_group_port     = 8000
  target_group_protocol = "HTTP"
  vpc_id                = module.vpc.vpc_id
  # instance_ids          = [module.ec2_be.instance_id]
  instance_ids          = []
}

module "target_group_frontend" {
  source                = "./modules/target_group"
  target_group_name     = "frontend-tg"
  target_group_port     = 3000
  target_group_protocol = "HTTP"
  vpc_id                = module.vpc.vpc_id
  instance_ids          = []
}


module "load_balancer" {
  source             = "./modules/load_balancer"
  load_balancer_name = "three-tier-alb"
  internal           = false
  security_group_ids = [module.sg_presentation.security_group_id]
  subnet_ids         = module.vpc.public_subnet_ids
  target_groups = [
    {
      port             = 80
      protocol         = "HTTP"
      target_group_arn = module.target_group_frontend.target_group_arn
    },
    {
      port             = 8000
      protocol         = "HTTP"
      target_group_arn = module.target_group_backend.target_group_arn
    }
  ]
}

module "asg_frontend" {
  source               = "./modules/asg"
  launch_template_name = "three-tier-launch-template-frontend"
  ami_id               = "ami-0ca4d5db4872d0c28" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type        = "t2.micro"
  key_name             = "tct-key-pair"
  user_data            = base64encode(templatefile("templates/user_data_fe.sh", { be_private_ip = module.load_balancer.alb_dns_name }))
  security_group_ids   = [module.sg_app.security_group_id]
  min_size             = 1
  desired_capacity     = 1
  max_size             = 3
  vpc_zone_identifiers = module.vpc.private_subnet_app_ids
  target_group_arns= [module.target_group_frontend.target_group_arn]

}

module "asg_backend" {
  source               = "./modules/asg"
  launch_template_name = "three-tier-launch-template-backend"
  ami_id               = "ami-0ca4d5db4872d0c28" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type        = "t2.micro"
  key_name             = "tct-key-pair"
  user_data          = base64encode(templatefile("templates/user_data_be.sh", { db_private_ip = module.ec2_db.private_ip }))
  security_group_ids   = [module.sg_app.security_group_id]
  min_size             = 1
  desired_capacity     = 1
  max_size             = 3
  vpc_zone_identifiers = module.vpc.private_subnet_app_ids
  target_group_arns= [module.target_group_backend.target_group_arn]

}

output "template_id" {
  value       = module.asg_frontend.launch_template_id
  description = "The ID of the launch template."

}