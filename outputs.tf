output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.this.arn
}

output "alb_target_group_arn" {
  description = "ARN of the ALB target group for nginx"
  value       = aws_lb_target_group.nginx.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.this.arn
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.nginx.name
}

output "ecs_task_definition_arn" {
  description = "ARN of the nginx ECS task definition"
  value       = aws_ecs_task_definition.nginx.arn
}

output "vpc_id" {
  description = "ID of the dedicated VPC"
  value       = aws_vpc.this.id
}
