variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "us-east-1"
  nullable    = false
}

variable "project_name" {
  description = "Base name used for resource naming and tagging"
  type        = string
  default     = "nginx-ecs"
  nullable    = false
}

variable "environment" {
  description = "Deployment environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  nullable    = false

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "vpc_cidr_block" {
  description = "CIDR block for the dedicated VPC"
  type        = string
  default     = "10.0.0.0/16"
  nullable    = false
}

variable "availability_zones" {
  description = "Map of availability zone suffixes to subnet index offsets"
  type        = map(number)
  default = {
    a = 0
    b = 1
  }
  nullable = false
}

variable "alb_ingress_cidr_ipv4" {
  description = "Allowed IPv4 CIDR block for inbound HTTP traffic to the Application Load Balancer"
  type        = string
  default     = "0.0.0.0/0"
  nullable    = false
}

variable "container_image" {
  description = "Container image URI for the nginx task"
  type        = string
  default     = "nginx:stable-alpine"
  nullable    = false
}

variable "container_port" {
  description = "Port exposed by the nginx container"
  type        = number
  default     = 80
  nullable    = false
}

variable "task_cpu" {
  description = "Fargate task CPU units (e.g., 256, 512, 1024)"
  type        = string
  default     = "256"
  nullable    = false
}

variable "task_memory" {
  description = "Fargate task memory in MiB (e.g., 512, 1024, 2048)"
  type        = string
  default     = "512"
  nullable    = false
}

variable "desired_count" {
  description = "Desired number of running ECS tasks"
  type        = number
  default     = 2
  nullable    = false
}

variable "assign_public_ip" {
  description = "Whether to assign a public IP to ECS Fargate tasks (set false when running in private subnets with NAT)"
  type        = bool
  default     = true
  nullable    = false
}

variable "create_custom_security_groups" {
  description = "Whether to create dedicated aws_security_group resources instead of using the VPC default security group (set false on AWS Emulator to avoid EC2 RevokeSecurityGroupEgress InvalidPermission.NotFound on custom VPCs)"
  type        = bool
  default     = false
  nullable    = false
}
