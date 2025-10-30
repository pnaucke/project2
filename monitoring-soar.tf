# CloudWatch Alarms, Lambda (SOAR), SNS, Dashboard

# CPU Alarms
resource "aws_cloudwatch_metric_alarm" "web1_cpu_alarm" {
  alarm_name          = "web1-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  dimensions = { InstanceId = aws_instance.web1.id }
  alarm_actions = [aws_lambda_function.soar_function.arn, aws_sns_topic.admin_notifications.arn]
}

resource "aws_cloudwatch_metric_alarm" "web2_cpu_alarm" {
  alarm_name          = "web2-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  dimensions = { InstanceId = aws_instance.web2.id }
  alarm_actions = [aws_lambda_function.soar_function.arn, aws_sns_topic.admin_notifications.arn]
}

# StatusCheckFailed Alarms
resource "aws_cloudwatch_metric_alarm" "web1_status_alarm" {
  alarm_name          = "web1-status-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  dimensions = { InstanceId = aws_instance.web1.id }
  alarm_actions = [aws_lambda_function.soar_function.arn, aws_sns_topic.admin_notifications.arn]
}

resource "aws_cloudwatch_metric_alarm" "web2_status_alarm" {
  alarm_name          = "web2-status-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  dimensions = { InstanceId = aws_instance.web2.id }
  alarm_actions = [aws_lambda_function.soar_function.arn, aws_sns_topic.admin_notifications.arn]
}

# SNS Topic
resource "aws_sns_topic" "admin_notifications" {
  name = "admin-notifications"
}

resource "aws_sns_topic_subscription" "admin_email" {
  topic_arn = aws_sns_topic.admin_notifications.arn
  protocol  = "email"
  endpoint  = "beheerder@example.com"
}

# Lambda IAM Role
data "aws_iam_policy_document" "soar_lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "soar_lambda_role" {
  name               = "soar-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.soar_lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "soar_lambda_basic" {
  role       = aws_iam_role.soar_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "soar_lambda_ec2" {
  role       = aws_iam_role.soar_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Lambda Function (via ZIP)
resource "aws_lambda_function" "soar_function" {
  filename         = "${path.module}/soar_function.zip"
  function_name    = "soar-function"
  role             = aws_iam_role.soar_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = filebase64sha256("${path.module}/soar_function.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.admin_notifications.arn
    }
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "web_dashboard" {
  dashboard_name = "webservers-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 6, height = 6,
        properties = {
          metrics = [
            ["AWS/EC2","CPUUtilization","InstanceId",aws_instance.web1.id],
            [".","CPUUtilization","InstanceId",aws_instance.web2.id]
          ],
          period = 60, stat = "Average", region = "eu-central-1", title = "CPU Usage"
        }
      },
      {
        type = "metric", x = 6, y = 0, width = 6, height = 6,
        properties = {
          metrics = [
            ["AWS/EC2","StatusCheckFailed","InstanceId",aws_instance.web1.id],
            [".","StatusCheckFailed","InstanceId",aws_instance.web2.id]
          ],
          period = 60, stat = "Maximum", region = "eu-central-1", title = "Status Check"
        }
      },
      {
        type = "text", x=0, y=6, width=6, height=2,
        properties = { markdown="### Web1 Uptime\n`Status: ${aws_cloudwatch_metric_alarm.web1_status_alarm.alarm_name}`" }
      },
      {
        type = "text", x=6, y=6, width=6, height=2,
        properties = { markdown="### Web2 Uptime\n`Status: ${aws_cloudwatch_metric_alarm.web2_status_alarm.alarm_name}`" }
      }
    ]
  })
}
