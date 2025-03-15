output "wordpress_ip" {
  value       = aws_instance.wordpress_app.public_ip
  description = "Public IP of WordPress instance"
}
