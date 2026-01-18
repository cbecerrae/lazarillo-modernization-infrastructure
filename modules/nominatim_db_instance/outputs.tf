output "instance_id" {
  description = "ID of the PostgreSQL EC2 instance"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP of the PostgreSQL instance"
  value       = aws_instance.this.private_ip
}

output "security_group_id" {
  description = "Security group protecting PostgreSQL"
  value       = aws_security_group.db.id
}

output "ebs_volume_ids" {
  description = "Map of attached EBS volume IDs"
  value       = { for name, vol in aws_ebs_volume.this : name => vol.id }
}