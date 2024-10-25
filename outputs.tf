output "wordpress_url" {
  value       = aws_lb.wordpress_lb.dns_name
  description = "The URL of the deployed WordPress service"
}
