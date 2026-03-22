# Deploying a Highly Available Web App on AWS Using Terraform

## Introduction
Yesterday I deployed a single web server. Today I'm tearing that apart and rebuilding it the right way. We're moving from hardcoded toy infrastructure to configurable, production-ready systems that can handle real traffic. The key? DRY (Don't Repeat Yourself) and understanding that single points of failure are unacceptable in production.

## The DRY Principle in Infrastructure
DRY (Don't Repeat Yourself) isn't just for application code. In Terraform, hardcoded values are technical debt:

- Inconsistency: Same value defined in multiple places drifts apart over time
- Maintenance nightmare: Changing a region means hunting through dozens of files
- Environment fragility: Development and production diverge because "someone forgot to update the staging config"
- Collaboration friction: Team members guess at values instead of using clear interfaces

Input variables solve this by creating a contract: "Here's what this module needs, and here are sensible defaults." The implementation stays clean; the configuration stays flexible.

## Phase 1: Refactoring to Configurable Infrastructure
First, I refactored my Day 3 server to use variables. Here's the evolution:
variables.tf — The contract:

```bash
hcl
Copy
variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8080
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}
main.tf — The implementation, now clean:
hcl
Copy
provider "aws" {
  region = var.region
}

resource "aws_security_group" "web_sg" {
  name        = "${var.environment}-web-sg"
  description = "Allow HTTP inbound traffic"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.ubuntu.id  # Using data source (see below)
  instance_type = var.instance_type
  
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  
  user_data = templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    environment = var.environment
  })

  tags = {
    Name        = "${var.environment}-web-server"
    Environment = var.environment
  }
}
Why these defaults?
server_port = 8080: Non-privileged port (no root needed), common for web apps behind load balancers
instance_type = "t2.micro": Free tier eligible, sufficient for development workloads
region = "us-east-1": Broadest service availability, cost-effective
environment = "dev": Safe default that won't accidentally deploy to production
Phase 2: Data Sources for Dynamic Configuration
Hardcoding AMI IDs is fragile—they vary by region and become outdated. Data sources query AWS dynamically:
hcl
Copy
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu) official account

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_availability_zones" "all" {
  state = "available"
}
The aws_ami data source finds the latest Ubuntu 22.04 AMI automatically. The aws_availability_zones data source (required for clustering) fetches active AZs dynamically—critical because AZ availability varies by account and region.
Phase 3: Building for Scale — The Clustered Architecture
A single server is a liability. If it fails, your service is down. If traffic spikes, it chokes. Here's the production architecture:
Architecture Components:
Launch Template: Blueprint for instances (AMI, instance type, user data, security groups)
Auto Scaling Group (ASG): Maintains 2-5 instances across multiple AZs, replacing unhealthy ones automatically
Application Load Balancer (ALB): Distributes HTTP requests across healthy instances
Target Group: Health checks and routing logic connecting ALB to ASG
Security Groups: Layered security—one for ALB (public-facing), one for instances (internal)
Complete Cluster Configuration:
hcl
Copy
# variables.tf additions for clustering
variable "cluster_name" {
  description = "Name for the cluster resources"
  type        = string
  default     = "terraform-web"
}

variable "min_size" {
  description = "Minimum number of instances in ASG"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of instances in ASG"
  type        = number
  default     = 5
}

variable "desired_capacity" {
  description = "Desired number of instances in ASG"
  type        = number
  default     = 2
}

# main.tf - Cluster resources

# Launch Template: The instance blueprint
resource "aws_launch_template" "web" {
  name_prefix   = "${var.cluster_name}-lt"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  
  vpc_security_group_ids = [aws_security_group.instance_sg.id]
  
  user_data = base64encode(templatefile("${path.module}/user-data.sh", {
    server_port = var.server_port
    environment = var.environment
  }))

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for ALB (public-facing)
resource "aws_security_group" "alb_sg" {
  name        = "${var.cluster_name}-alb-sg"
  description = "Security group for ALB"

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

# Security Group for Instances (internal, from ALB only)
resource "aws_security_group" "instance_sg" {
  name        = "${var.cluster_name}-instance-sg"
  description = "Security group for web instances"

  ingress {
    from_port       = var.server_port
    to_port         = var.server_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]  # Only from ALB
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer
resource "aws_lb" "web" {
  name               = "${var.cluster_name}-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb_sg.id]
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Target Group for ASG attachment
resource "aws_lb_target_group" "web" {
  name     = "${var.cluster_name}-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name                = "${var.cluster_name}-asg"
  vpc_zone_identifier = data.aws_subnets.default.ids
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"  # Use ALB health checks, not just EC2 status

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
}

# Data sources for networking
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# outputs.tf
output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.web.dns_name
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}
The User Data Script (user-data.sh):
bash
Copy
#!/bin/bash
apt-get update
apt-get install -y apache2
systemctl start apache2
systemctl enable apache2

cat > /var/www/html/index.html <<EOF
<h1>Hello from Terraform Cluster!</h1>
<p>Environment: ${environment}</p>
<p>Server Port: ${server_port}</p>
<p>Hostname: $(hostname)</p>
<p>Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
EOF

# Configure Apache to listen on the correct port
sed -i "s/Listen 80/Listen ${server_port}/g" /etc/apache2/ports.conf
sed -i "s/:80/:${server_port}/g" /etc/apache2/sites-enabled/000-default.conf
systemctl restart apache2
Key Architectural Decisions:
Separate Security Groups: ALB security group allows public HTTP (port 80). Instance security group only allows traffic from the ALB on the application port (8080). This is defense in depth—even if the instance security group is misconfigured, the ALB acts as a shield.
Health Checks: The target group health check pings / every 15 seconds. If an instance fails twice consecutively, it's marked unhealthy and replaced by the ASG. This provides automatic healing.
Multi-AZ Deployment: The ASG spans all available AZs in the region. If an entire availability zone fails, traffic routes to healthy instances in other zones.
Launch Template Lifecycle: create_before_destroy ensures new instances are healthy before old ones are terminated during updates—zero-downtime deployments.
Deployment and Verification
bash
Copy
terraform init
terraform plan
terraform apply

# Output:
alb_dns_name = "terraform-web-alb-123456789.us-east-1.elb.amazonaws.com"
asg_name     = "terraform-web-asg"
Testing the deployment:
bash
Copy
curl http://terraform-web-alb-123456789.us-east-1.elb.amazonaws.com
Response:
HTML
Preview
Copy
<h1>Hello from Terraform Cluster!</h1>
<p>Environment: dev</p>
<p>Server Port: 8080</p>
<p>Hostname: ip-172-31-45-123</p>
<p>Instance ID: i-0a1b2c3d4e5f67890</p>
Running curl multiple times shows different hostnames—proof the load balancer is distributing traffic across multiple instances.
What I Learned from the Documentation
Spending time in the official docs revealed nuances:
aws_autoscaling_group: The health_check_type = "ELB" is crucial—without it, the ASG only checks if the EC2 instance is running, not if it's actually serving HTTP traffic
aws_lb: Application Load Balancers operate at Layer 7 (HTTP), enabling path-based routing and host-based routing (not used here, but powerful)
Input variables: The validation block can enforce constraints (e.g., instance_type must start with "t2" or "t3")
Data sources: The depends_on meta-argument can force data sources to refresh in specific orders when implicit dependencies aren't enough
What Broke and How I Fixed It
Table
Issue	Symptom	Root Cause	Fix
ASG instances failing health checks	Target group showed "unhealthy"	Security group blocked ALB traffic to instances	Updated instance security group to allow port 8080 from ALB security group ID, not CIDR blocks
503 errors from ALB	Browser showed "503 Service Temporarily Unavailable"	ASG hadn't finished launching instances when I tested	Added min_elb_capacity = 2 to ASG to wait for healthy instances before considering apply complete
User data script not executing	Apache not installed, default page showed	Launch template user data must be base64 encoded	Wrapped templatefile() with base64encode() in launch template
Instances in only one AZ	All instances had same subnet	vpc_zone_identifier only had one subnet ID	Used data.aws_subnets.default.ids to get all default VPC subnets across AZs
The Difference: Day 3 vs. Day 4
Table
Aspect	Day 3 (Single Server)	Day 4 (Clustered)
Availability	Single point of failure	Multi-AZ redundancy
Scalability	Manual resizing	Automatic scaling (2-5 instances)
Health Management	Manual monitoring	Automatic replacement of unhealthy instances
Configuration	Hardcoded values	Variables for all tunable parameters
Security	Single security group	Layered security (ALB + instance SGs)
Traffic Handling	Direct to instance	Load balanced across pool
Updates	Downtime required	Rolling updates possible
Conclusion
Moving from a single server to a clustered, load-balanced architecture taught me that production infrastructure is about resilience, not just functionality. Input variables enforce the DRY principle, making configurations maintainable across teams and environments. Data sources eliminate brittle hardcoding. Auto Scaling Groups and Load Balancers transform fragile servers into robust systems.
This isn't just "more complex"—it's fundamentally different. A single server is a liability; a cluster is a service. Tomorrow I explore state management, which becomes critical when multiple people work on the same infrastructure.
