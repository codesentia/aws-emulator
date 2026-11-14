# Native OpenTofu tests (`tofu test`)
# Can be executed locally with: ( . ~/.aws/emulator/9297.env && tofu test )

run "validate_ecs_nginx_alb_plan" {
  command = plan

  assert {
    condition     = aws_ecs_cluster.this.name == "nginx-ecs-dev-cluster"
    error_message = "Expected ECS cluster name to be nginx-ecs-dev-cluster"
  }

  assert {
    condition     = aws_ecs_task_definition.nginx.network_mode == "awsvpc"
    error_message = "Fargate task definition must use awsvpc network mode"
  }

  assert {
    condition     = contains(aws_ecs_task_definition.nginx.requires_compatibilities, "FARGATE")
    error_message = "Task definition must require FARGATE compatibility"
  }

  assert {
    condition     = aws_ecs_service.nginx.launch_type == "FARGATE"
    error_message = "ECS service must use FARGATE launch type"
  }

  assert {
    condition     = aws_ecs_service.nginx.desired_count == 2
    error_message = "ECS service desired count should default to 2"
  }

  assert {
    condition     = aws_lb.this.load_balancer_type == "application" && aws_lb.this.drop_invalid_header_fields == true
    error_message = "ALB must be application type with drop_invalid_header_fields enabled"
  }

  assert {
    condition     = aws_lb_target_group.nginx.target_type == "ip" && aws_lb_target_group.nginx.port == 80
    error_message = "ALB target group for Fargate must use ip target_type on port 80"
  }

  assert {
    condition     = aws_lb_listener.http.port == 80 && aws_lb_listener.http.protocol == "HTTP"
    error_message = "ALB listener must listen on HTTP port 80"
  }
}
