variable "user_data" {
  description = "User data script to initialize the EC2 instance"
  type        = string
  default     = <<-EOF
#!/bin/bash
exec > /var/log/userdata.log 2>&1
set -ex

dnf update -y
dnf install -y httpd

systemctl enable --now httpd

echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
EOF
}


variable "user_data_db" {
  description = "User data script to initialize the EC2 instance"
  type        = string
  default     = <<-EOF
#!/bin/bash
sudo yum update -y
sudo amazon-linux-extras enable docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker
sudo yum install -y git
git clone https://github.com/TranChucThien/terraform-aws-3-tier-architecture.git
cd terraform-aws-3-tier-architecture/application/db

sudo mkdir -p /usr/libexec/docker/cli-plugins
sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose

sudo docker compose version
sudo docker compose up -d
EOF
}

variable "user_data_be" {
  description = "User data script to initialize the EC2 instance"
  type        = string
  default     = <<-EOF
#!/bin/bash
sudo yum update -y
sudo amazon-linux-extras enable docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker
sudo yum install -y git
git clone https://github.com/TranChucThien/terraform-aws-3-tier-architecture.git
cd terraform-aws-3-tier-architecture/application/backend

sudo mkdir -p /usr/libexec/docker/cli-plugins
sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose

sudo docker compose version
sudo docker compose up -d
EOF
}

variable "user_data_fe" {
  description = "User data script to initialize the EC2 instance"
  type        = string
  default     = <<-EOF
#!/bin/bash
sudo yum update -y
sudo amazon-linux-extras enable docker
sudo yum install -y docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
newgrp docker
sudo yum install -y git
git clone https://github.com/TranChucThien/terraform-aws-3-tier-architecture.git
cd terraform-aws-3-tier-architecture/application/frontend

sudo mkdir -p /usr/libexec/docker/cli-plugins
sudo curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m)" -o /usr/libexec/docker/cli-plugins/docker-compose
sudo chmod +x /usr/libexec/docker/cli-plugins/docker-compose

sudo docker compose version
sudo docker compose up -d
EOF
}