# Terraform configuration for scalable web application infrastructure on AWS
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data Sources - Dynamic discovery of AWS resources
data "aws_availability_zones" "all" {
  state = "available"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for ALB - Public-facing
resource "aws_security_group" "alb_sg" {
  name        = "${var.cluster_name}-alb-sg"
  description = "Security group for ALB - allows public HTTP"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-alb-sg"
    Environment = var.environment
  }
}

# Security Group for Instances - Internal only
resource "aws_security_group" "instance_sg" {
  name        = "${var.cluster_name}-instance-sg"
  description = "Security group for web instances - ALB access only"

  ingress {
    from_port       = var.server_port
    to_port         = var.server_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
    description     = "Allow traffic only from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.cluster_name}-instance-sg"
    Environment = var.environment
  }
}

# Launch Template - Blueprint for ASG instances
resource "aws_launch_template" "web" {
  name_prefix   = "${var.cluster_name}-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    environment = var.environment
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "${var.cluster_name}-instance"
      Environment = var.environment
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Application Load Balancer
resource "aws_lb" "web" {
  name               = "${var.cluster_name}-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb_sg.id]

  tags = {
    Name        = "${var.cluster_name}-alb"
    Environment = var.environment
  }
}

# Target Group - Health checks and routing
resource "aws_lb_target_group" "web" {
  name     = "${var.cluster_name}-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 15
    path                = "/"
    port                = "traffic-port"
    matcher             = "200"
    protocol            = "HTTP"
  }

  tags = {
    Name        = "${var.cluster_name}-tg"
    Environment = var.environment
  }
}

# ALB Listener - Routes incoming traffic
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Auto Scaling Group - Manages instance fleet
resource "aws_autoscaling_group" "web" {
  name                = "${var.cluster_name}-asg"
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"  # Use ALB health checks, not just EC2
  health_check_grace_period = 300

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "Terraform"
    propagate_at_launch = true
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "valmoe-terraform-state-bucket"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

#Needed for state locking to prevent concurrent modifications within teams
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "valmoe-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

#Comment out the backend configuration for local state storage until we set up the S3 bucket and DynamoDB table for remote state management
# Backend configuration for remote state storage in S3 with DynamoDB for locking
terraform {
  backend "s3" {
    bucket         = "valmoe-terraform-state-bucket"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    use_lockfile    = true
  }
}