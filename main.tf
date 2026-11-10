terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.72.0"
    }
  }
}

variable "aws_profile" {
  description = "AWS CLI profile to use. No default on purpose, so the reproduction never runs against an account by accident."
  type        = string
}

variable "region" {
  description = "AWS Region to register the task definition in."
  type        = string
  default     = "eu-central-1"
}

provider "aws" {
  profile = var.aws_profile
  region  = var.region
}

# Minimal reproduction: a FireLens log router container that does not set "user".
# Only a task definition is registered (no service, no running tasks), which is free.
resource "aws_ecs_task_definition" "repro" {
  family                   = "tf-firelens-user-repro"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  container_definitions = jsonencode([
    {
      name      = "log_router"
      image     = "public.ecr.aws/aws-observability/aws-for-fluent-bit:stable"
      essential = true
      firelensConfiguration = {
        type = "fluentbit"
      }
    },
    {
      name      = "app"
      image     = "public.ecr.aws/docker/library/busybox:latest"
      essential = true
      logConfiguration = {
        logDriver = "awsfirelens"
        options   = { Name = "stdout" }
      }
    },
  ])
}
