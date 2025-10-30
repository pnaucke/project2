# ----------------------
# SNS Topic for Alerts
# ----------------------
resource "aws_sns_topic" "admin_notifications" {
  name = "admin-alerts-topic"
}

resource "aws_sns_topic_subscription" "admin_email" {
  topic_arn = aws_sns_topic.admin_notifications.arn
  protocol  = "email"
  endpoint  = "554603@student.fontys.nl"
}

# ----------------------
# IAM Role for Lambda
# ----------------------
resource "aws_iam_role" "soar_lambda_role" {
  name = "soar-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "soar_lambda_basic_execution" {
  role       = aws_iam_role.soar_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "soar_lambda_ec2_policy" {
  role       = aws_iam_role.soar_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "soar_lambda_sns_policy" {
  role       = aws_iam_role.soar_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

# ----------------------
# SOAR Lambda Function
# ----------------------
resource "aws_lambda_function" "soar_function" {
  function_name = "soar-function"
  role          = aws_iam_role.soar_lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  filename      = "soar_function.zip"
  source_code_hash = filebase64sha256("soar_function.zip")

  environment {
    variables = {
      SNS_TOPIC_ARN = aws_sns_topic.admin_notifications.arn
    }
  }

  timeout = 30
}

# ----------------------
# CloudWatch Alarms
# ----------------------

# CPU >= 80% -> Trigger SOAR Lambda & mail
resource "aws_cloudwatch_metric_alarm" "cpu_high_web1" {
  alarm_name          = "web1-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU usage too high on web1"
  dimensions = {
    InstanceId = aws_instance.web1.id
  }
  alarm_actions = [
    aws_sns_topic.admin_notifications.arn,
    aws_lambda_function.soar_function.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "cpu_high_web2" {
  alarm_name          = "web2-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU usage too high on web2"
  dimensions = {
    InstanceId = aws_instance.web2.id
  }
  alarm_actions = [
    aws_sns_topic.admin_notifications.arn,
    aws_lambda_function.soar_function.arn
  ]
}

# Webserver Down -> mail & SOAR trigger
resource "aws_cloudwatch_metric_alarm" "web1_status_alarm" {
  alarm_name          = "web1-status-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed_Instance"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Web1 instance might be down"
  dimensions = {
    InstanceId = aws_instance.web1.id
  }
  alarm_actions = [
    aws_sns_topic.admin_notifications.arn,
    aws_lambda_function.soar_function.arn
  ]
}

resource "aws_cloudwatch_metric_alarm" "web2_status_alarm" {
  alarm_name          = "web2-status-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed_Instance"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  alarm_description   = "Web2 instance might be down"
  dimensions = {
    InstanceId = aws_instance.web2.id
  }
  alarm_actions = [
    aws_sns_topic.admin_notifications.arn,
    aws_lambda_function.soar_function.arn
  ]
}

# ----------------------
# EventBridge Rule (Trigger SOAR Lambda)
# ----------------------
resource "aws_cloudwatch_event_rule" "alarm_trigger" {
  name        = "soar-alarm-trigger"
  description = "Triggers Lambda when a CloudWatch alarm changes state"

  event_pattern = jsonencode({
    "source" : ["aws.cloudwatch"],
    "detail-type" : ["CloudWatch Alarm State Change"]
  })
}

resource "aws_cloudwatch_event_target" "soar_target" {
  rule      = aws_cloudwatch_event_rule.alarm_trigger.name
  arn       = aws_lambda_function.soar_function.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar_function.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.alarm_trigger.arn
}

# ----------------------
# Data lookup for dashboard
# ----------------------
data "aws_lb_target_group" "web_tg_data" {
  arn = aws_lb_target_group.web_tg.arn
}

# ----------------------
# CloudWatch Dashboard
# ----------------------
resource "aws_cloudwatch_dashboard" "web_dashboard" {
  dashboard_name = "web-monitoring-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text",
        x    = 0,
        y    = 0,
        width = 24,
        height = 1,
        properties = {
          markdown = "# 🌐 Web Monitoring Dashboard"
        }
      },
      {
        type = "metric",
        x    = 0,
        y    = 1,
        width = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.web1.id, { label: "Web1 CPU (%)" }],
            ["AWS/EC2", "CPUUtilization", "InstanceId", aws_instance.web2.id, { label: "Web2 CPU (%)" }]
          ],
          period = 60,
          stat   = "Average",
          region = "eu-central-1",
          title  = "CPU Usage per Webserver"
        }
      },
      {
        type = "metric",
        x    = 12,
        y    = 1,
        width = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", data.aws_lb_target_group.web_tg_data.arn_suffix, "LoadBalancer", aws_lb.web_lb.arn_suffix, { label: "Healthy Hosts (Uptime)" }]
          ],
          period = 60,
          stat   = "Average",
          region = "eu-central-1",
          title  = "Webserver Uptime (HealthyHostCount ≥ 1)"
        }
      },
      {
        type = "metric",
        x    = 0,
        y    = 7,
        width = 24,
        height = 6,
        properties = {
          metrics = [
            ["AWS/EC2", "StatusCheckFailed_Instance", "InstanceId", aws_instance.web1.id, { label: "Web1 Uptime Status" }],
            ["AWS/EC2", "StatusCheckFailed_Instance", "InstanceId", aws_instance.web2.id, { label: "Web2 Uptime Status" }]
          ],
          view   = "timeSeries",
          stacked = false,
          region = "eu-central-1",
          title  = "Webserver Status (0 = Up, 1 = Down)"
        }
      }
    ]
  })
}
