 #  terraform init
 #  terraform plan / validate
 #  terraform apply

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.45.0"
    }
  }
}

// Can be provided in environment variables: export TF_VAR_aws_access_key=xxx
variable "aws_access_key" {
  type        = string
  description = "AWS Access key"
 
#   validation {
#     condition     = length(var.image_id) > 4 && substr(var.image_id, 0, 4) == "ami-"
#     error_message = "The image_id value must be a valid AMI id, starting with \"ami-\"."
#   }
}

// Can be provided in environment variables: export TF_VAR_aws_secret=xxx
variable "aws_secret" {
  type        = string
  description = "AWS Secret"
}

// Can be provided in environment variables: export TF_VAR_aws_region=xxx
variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "us-east-2"
}

provider "aws" {
  region  = var.aws_region # The region where environment is going to be deployed # Use your own region here
  access_key = var.aws_access_key # Get AWS Access key from env. vars
  secret_key = var.aws_secret # Get AWS Secret from env. vars
}

resource "aws_ecr_repository" "app_ecr_repo" {
  name = "aws-docker-repo"
}

resource "aws_ecs_cluster" "my_cluster" {
  name = "aws-docker-cluster" # Name your cluster here
}

resource "aws_ecs_task_definition" "app_task" {
  family                   = "aws-docker-app-task" # Name your task
  container_definitions    = <<DEFINITION
  [
    {
      "name": "aws-docker-app-task",
      "image": "${aws_ecr_repository.app_ecr_repo.repository_url}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 8080
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # use Fargate as the lauch type
  network_mode             = "awsvpc"    # add the awsvpc network mode as this is required for Fargate
  memory                   = 512         # Specify the memory the container requires
  cpu                      = 256         # Specify the CPU the container requires
  execution_role_arn       = "${aws_iam_role.ecs_task_exec_role.arn}"
}

resource "aws_iam_role" "ecs_task_exec_role" {
  name               = "aws-docker-ecs-task-exec-role"
  assume_role_policy = "${data.aws_iam_policy_document.assume_role_policy.json}"
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = "${aws_iam_role.ecs_task_exec_role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Provide a reference to your default VPC
resource "aws_default_vpc" "default_vpc" {
}

# Provide references to your default subnets
resource "aws_default_subnet" "default_subnet_a" {
  # Specify region here but reference to subnet 1a
  # could possibly improve this by using "${var.aws_region}a/b"
  availability_zone = "us-east-2a"
}

resource "aws_default_subnet" "default_subnet_b" {
  # Specify region here but reference to subnet 1b
  availability_zone = "us-east-2b"
}

resource "aws_alb" "application_load_balancer" {
  name               = "aws-docker-load-balancer-dev" # Naming our load balancer
  load_balancer_type = "application"
  subnets = [ # Referencing the default subnets
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}"
  ]
  # Referencing the security group
  security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
}

# Creating a security group for the load balancer:
resource "aws_security_group" "load_balancer_security_group" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "aws-docker-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = "${aws_default_vpc.default_vpc.id}" # Referencing the default VPC
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = "${aws_alb.application_load_balancer.arn}" # Referencing our load balancer
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.target_group.arn}" # Referencing our target group
  }
}

resource "aws_ecs_service" "app_service" {
  name            = "aws-docker-app-service"                             # Name the  service
  cluster         = "${aws_ecs_cluster.my_cluster.id}"             # Reference the created Cluster
  task_definition = "${aws_ecs_task_definition.app_task.arn}" # Reference the task that the service will spin up
  launch_type     = "FARGATE"
  desired_count   = 3 # Set up the number of containers to 3

  load_balancer {
    target_group_arn = "${aws_lb_target_group.target_group.arn}" # Reference the target group
    container_name   = "${aws_ecs_task_definition.app_task.family}"
    container_port   = 8080 # Port exposed by the docker image
  }

  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}"]
    assign_public_ip = true                                                # Provide the containers with public IPs
    security_groups  = ["${aws_security_group.service_security_group.id}"] # Set up the security group
  }
}

resource "aws_security_group" "service_security_group" {
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    # Only allowing traffic in from the load balancer security group
    security_groups = ["${aws_security_group.load_balancer_security_group.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Log the load balancer app url
output "app_url" {
  value = aws_alb.application_load_balancer.dns_name
}