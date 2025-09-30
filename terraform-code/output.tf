# output "db_private_ip" {
#   value       = module.ec2_db.private_ip
#   description = "The private IP address of the EC2 instance."

# }

# output "be_private_ip" {
#   value       = module.ec2_be.private_ip
#   description = "The private IP address of the EC2 instance."

# }


# output "fe_private_ip" {
#   value       = try(module.ec2_fe.private_ip, null)
#   description = "The private IP address of the EC2 instance."

# }

output "dns_name" {
  value       = module.load_balancer.alb_dns_name
  description = "The DNS name of the load balancer."

}

output "ec2_bastion_host_public_ip" {
  value       = module.ec2_bastion_host.public_ip
  description = "The public IP address of the Bastion Host EC2 instance."

}

