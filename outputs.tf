output "wordpress_ip" {
  value       = aws_instance.wordpress.public_ip
  description = "Public IP of WordPress instance"
}
