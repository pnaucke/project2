output "load_balancer_dns" {
  value = aws_lb.web_lb.dns_name
}

output "db_endpoint" {
  value = aws_db_instance.db.address
}

output "grafana_private_ip" {
  value = aws_instance.grafana.private_ip
}

output "soar_private_ip" {
  value = aws_instance.soar.private_ip
}