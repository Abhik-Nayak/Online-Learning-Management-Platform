# Values printed after `terraform apply` (and by `terraform output`).
# Ansible's inventory will be built from these in a later task.

# ---------------------------------------------------------------- Network
output "vpc_id" {
  description = "ID of the LMS VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the two public (app) subnets"
  value       = aws_subnet.public[*].id
}

output "db_subnet_id" {
  description = "ID of the DB subnet"
  value       = aws_subnet.db.id
}

# ---------------------------------------------------------------- Instance IDs
output "app_1_instance_id" {
  value = aws_instance.app_1.id
}

output "app_2_instance_id" {
  value = aws_instance.app_2.id
}

output "db_instance_id" {
  value = aws_instance.db.id
}

# ---------------------------------------------------------------- Public IPs
output "app_1_public_ip" {
  value = aws_instance.app_1.public_ip
}

output "app_2_public_ip" {
  value = aws_instance.app_2.public_ip
}

output "db_public_ip" {
  description = "Used only for SSH from the Management Server (db-sg blocks everything else)"
  value       = aws_instance.db.public_ip
}

# ---------------------------------------------------------------- Private IPs
output "app_1_private_ip" {
  value = aws_instance.app_1.private_ip
}

output "app_2_private_ip" {
  value = aws_instance.app_2.private_ip
}

output "db_private_ip" {
  description = "The app servers connect to PostgreSQL on this IP"
  value       = aws_instance.db.private_ip
}
