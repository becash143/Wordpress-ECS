terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "your-unique-s3-bucket-name" # Change to a unique bucket name
    key            = "terraform/state"
    region         = var.region
  }
}

provider "aws" {
  region = var.region
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnet" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group" "ecs_security_group" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecr_repository" "wordpress" {
  name = "wordpress-app"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name = "wordpress-db-credentials"
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/wordpress"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "wordpress_cluster" {
  name = "wordpress-cluster"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  ]
}

resource "aws_iam_role_policy" "s3_access" {
  name   = "S3AccessPolicy"
  role   = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::your-unique-s3-bucket-name",                     # The bucket itself
          "arn:aws:s3:::your-unique-s3-bucket-name/*"                  # All objects within the bucket
        ]
      }
    ]
  })
}

resource "aws_rds_instance" "wordpress_db" {
  allocated_storage      = 20
  engine                = "mysql"
  instance_class        = "db.t3.micro"
  name                  = "wordpress"
  username              = "admin"
  password              = random_password.db_password.result
  parameter_group_name  = "default.mysql8.0"
  publicly_accessible    = true
  skip_final_snapshot    = true
}

resource "random_password" "db_password" {
  length  = 16
  special = false
}

# Application Load Balancer
resource "aws_lb" "wordpress_lb" {
  name               = "wordpress-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ecs_security_group.id]
  subnets            = aws_subnet.public_subnet[*].id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.wordpress_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
  }
}

resource "aws_lb_target_group" "wordpress_tg" {
  name     = "wordpress-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold  = 2
    unhealthy_threshold = 2
  }
}

resource "aws_ecs_service" "wordpress_service" {
  name            = "wordpress-service"
  cluster         = aws_ecs_cluster.wordpress_cluster.id
  task_definition = aws_ecs_task_definition.wordpress.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.public_subnet[*].id
    security_groups  = [aws_security_group.ecs_security_group.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.wordpress_tg.arn
    container_name   = "wordpress"
    container_port   = 80
  }
}

resource "aws_ecs_task_definition" "wordpress" {
  family                   = "wordpress-task"
  container_definitions    = <<DEFINITION
[
  {
    "name": "wordpress",
    "image": "${aws_ecr_repository.wordpress.repository_url}:latest",
    "memory": 512,
    "cpu": 256,
    "essential": true,
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ],
    "environment": [
      {
        "name": "WORDPRESS_DB_HOST",
        "value": "${aws_rds_instance.wordpress_db.address}"
      }
    ],
    "secrets": [
      {
        "name": "WORDPRESS_DB_USER",
        "valueFrom": "${aws_secretsmanager_secret.db_credentials.arn}:username"
      },
      {
        "name": "WORDPRESS_DB_PASSWORD",
        "valueFrom": "${aws_secretsmanager_secret.db_credentials.arn}:password"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/wordpress",
        "awslogs-region": "${var.region}",
        "awslogs-stream-prefix": "ecs"
      }
    }
  }
]
DEFINITION
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
}
