locals {
  name_prefix                 = "${var.project_name}-${var.environment}"
  alb_security_group_id       = var.create_custom_security_groups ? aws_security_group.alb[0].id : aws_vpc.this.default_security_group_id
  ecs_tasks_security_group_id = var.create_custom_security_groups ? aws_security_group.ecs_tasks[0].id : aws_vpc.this.default_security_group_id
}

# ------------------------------------------------------------------------------
# Networking (Dedicated VPC & Subnets)
# ------------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = var.availability_zones

  availability_zone       = "${var.aws_region}${each.key}"
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 8, each.value)
  map_public_ip_on_launch = false
  vpc_id                  = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-public-${each.key}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

resource "aws_route" "public_internet" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
  route_table_id         = aws_route_table.public.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  route_table_id = aws_route_table.public.id
  subnet_id      = each.value.id
}

# ------------------------------------------------------------------------------
# Security Groups (Separate Rule Resources per AWS Provider v5+ Best Practices)
# ------------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  count = var.create_custom_security_groups ? 1 : 0

  description = "Security group for the Application Load Balancer"
  name        = "${local.name_prefix}-alb-sg"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  cidr_ipv4         = var.alb_ingress_cidr_ipv4
  description       = "Allow inbound HTTP traffic"
  from_port         = 80
  ip_protocol       = "tcp"
  security_group_id = local.alb_security_group_id
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ecs" {
  description                  = "Forward traffic to ECS tasks on container port"
  from_port                    = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = local.ecs_tasks_security_group_id
  security_group_id            = local.alb_security_group_id
  to_port                      = var.container_port
}

resource "aws_security_group" "ecs_tasks" {
  count = var.create_custom_security_groups ? 1 : 0

  description = "Security group for ECS Fargate nginx tasks"
  name        = "${local.name_prefix}-ecs-tasks-sg"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${local.name_prefix}-ecs-tasks-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  description                  = "Allow inbound traffic from the ALB only"
  from_port                    = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = local.alb_security_group_id
  security_group_id            = local.ecs_tasks_security_group_id
  to_port                      = var.container_port
}

resource "aws_vpc_security_group_egress_rule" "ecs_https_out" {
  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow outbound HTTPS for container image pulls and CloudWatch logs"
  from_port         = 443
  ip_protocol       = "tcp"
  security_group_id = local.ecs_tasks_security_group_id
  to_port           = 443
}

# ------------------------------------------------------------------------------
# Application Load Balancer (ALB)
# ------------------------------------------------------------------------------

resource "aws_lb" "this" {
  drop_invalid_header_fields = true
  internal                   = false
  load_balancer_type         = "application"
  name                       = "${local.name_prefix}-alb"
  security_groups            = [local.alb_security_group_id]
  subnets                    = [for s in aws_subnet.public : s.id]

  tags = {
    Name = "${local.name_prefix}-alb"
  }
}

resource "aws_lb_target_group" "nginx" {
  deregistration_delay = 30
  name                 = "${local.name_prefix}-tg"
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = aws_vpc.this.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.name_prefix}-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.nginx.arn
    type             = "forward"
  }
}

# ------------------------------------------------------------------------------
# IAM Execution & Task Roles for ECS
# ------------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_tasks_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"

    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
  name               = "${local.name_prefix}-execution-role"

  tags = {
    Name = "${local.name_prefix}-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution.name
}

resource "aws_iam_role" "ecs_task" {
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume_role.json
  name               = "${local.name_prefix}-task-role"

  tags = {
    Name = "${local.name_prefix}-task-role"
  }
}

# ------------------------------------------------------------------------------
# CloudWatch Log Group & ECS Cluster / Task / Service
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "nginx" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 14

  tags = {
    Name = "${local.name_prefix}-logs"
  }
}

resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${local.name_prefix}-cluster"
  }
}

resource "aws_ecs_task_definition" "nginx" {
  cpu                      = var.task_cpu
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  family                   = "${local.name_prefix}-nginx"
  memory                   = var.task_memory
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  task_role_arn            = aws_iam_role.ecs_task.arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name        = "nginx"
      image       = var.container_image
      essential   = true
      stopTimeout = 30
      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.nginx.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "nginx"
        }
      }
    }
  ])

  tags = {
    Name = "${local.name_prefix}-task-def"
  }
}

resource "aws_ecs_service" "nginx" {
  cluster          = aws_ecs_cluster.this.id
  desired_count    = var.desired_count
  launch_type      = "FARGATE"
  name             = "${local.name_prefix}-service"
  platform_version = "1.4.0"
  task_definition  = aws_ecs_task_definition.nginx.arn

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  load_balancer {
    container_name   = "nginx"
    container_port   = var.container_port
    target_group_arn = aws_lb_target_group.nginx.arn
  }

  network_configuration {
    assign_public_ip = var.assign_public_ip
    security_groups  = [local.ecs_tasks_security_group_id]
    subnets          = [for s in aws_subnet.public : s.id]
  }

  tags = {
    Name = "${local.name_prefix}-service"
  }

  depends_on = [aws_lb_listener.http]
}
