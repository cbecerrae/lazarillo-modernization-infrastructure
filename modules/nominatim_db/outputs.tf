output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "postgresql_endpoint" {
  description = "PostgreSQL service endpoint"
  value = "postgresql.${local.name}.ecs.internal"
}