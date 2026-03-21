output "public_ip" {
  description = "Public IP of the web server"
  value       = aws_instance.web_server.public_ip
}

output "public_url" {
  description = "URL to access the web server"
  value       = "http://${aws_instance.web_server.public_ip}"
}

output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.web_server.id
}