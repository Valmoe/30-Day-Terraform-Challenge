output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.web.dns_name
}

output "alb_zone_id" {
  description = "Route 53 zone ID of the load balancer"
  value       = aws_lb.web.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.web.arn
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "asg_min_size" {
  description = "Minimum size of the ASG"
  value       = aws_autoscaling_group.web.min_size
}

output "asg_max_size" {
  description = "Maximum size of the ASG"
  value       = aws_autoscaling_group.web.max_size
}