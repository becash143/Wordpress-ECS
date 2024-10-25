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

resource "aws_ecs_service" "wordpress_service" {
  name            = "wordpress-service"
  cluster         = aws_ecs_cluster.wordpress_cluster.id
  task_definition = aws_ecs_task_definition.wordpress.arn
  desired_count   = 2

  network_configuration {
    subnets          = aws_subnet.public_subnet[*].id
    security_groups  = [aws_security_group.ecs_security_group.id]
    assign_public_ip = true
  }
}
