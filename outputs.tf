output "load_balancer_dns" {
  value = aws_lb.web_lb.dns_name
}

output "db_endpoint" {
  value = aws_db_instance.db.address
}

output "soar_lambda_arn" {
  value = aws_lambda_function.soar_lambda.arn
}
