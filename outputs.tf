output "web_lb_dns" {
  value = aws_lb.web_lb.dns_name
}

output "db_endpoint" {
  value = aws_db_instance.db.address
}

output "soar_lambda_name" {
  value = aws_lambda_function.soar_lambda.function_name
}

output "grafana_workspace_id" {
  value = aws_grafana_workspace.grafana.id
}
