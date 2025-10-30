variable "alert_email" {
  description = "Email to send alerts to"
  type        = string
  sensitive   = true
}

# ----------------------
# IAM Role voor Lambda
# ----------------------
resource "aws_iam_role" "lambda_role" {
  name = "soar_monitoring_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_full" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

# ----------------------
# Lambda function voor monitoring
# ----------------------
resource "aws_lambda_function" "soar_monitor" {
  filename         = "lambda_function.zip"
  function_name    = "soar_monitor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"

  environment {
    variables = {
      ALERT_EMAIL = var.alert_email
      WEB1_IP     = aws_instance.web1.private_ip
      WEB2_IP     = aws_instance.web2.private_ip
    }
  }
}

# ----------------------
# CloudWatch Alarms
# ----------------------
resource "aws_cloudwatch_metric_alarm" "web1_cpu" {
  alarm_name          = "web1_cpu_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = [aws_lambda_function.soar_monitor.arn]
  dimensions = {
    InstanceId = aws_instance.web1.id
  }
}

resource "aws_cloudwatch_metric_alarm" "web2_cpu" {
  alarm_name          = "web2_cpu_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_actions       = [aws_lambda_function.soar_monitor.arn]
  dimensions = {
    InstanceId = aws_instance.web2.id
  }
}
