output "ec2_db_public_ip" {
  value = module.ec2_db.*.public_ip
  
}