# Provider
provider "aws" {
  region = var.aws_region
}

# Fetch latest Amazon Linux 2 AMI automatically
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# VPC - use default
data "aws_vpc" "default" {
  default = true
}

# Security Group - allow HTTP and SSH
resource "aws_security_group" "web_sg" {
  name        = "web_server_sg"
  description = "Allow HTTP inbound traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from Internet"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict to your IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "web_server_sg"
    Purpose = "30 Day Terraform Challenge - Day 3"
  }
}

# EC2 Instance
resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<html>
      <head><title>Day 3 - Terraform Web Server</title></head>
      <body>
        <h1>Hello from Terraform!</h1>
        <p>Deployed by: Valmoe</p>
        <p>30 Day Terraform Challenge - Day 3</p>
      </body>
    </html>" > /var/www/html/index.html
  EOF

  tags = {
    Name    = "web_server"
    Purpose = "30 Day Terraform Challenge - Day 3"
  }
}