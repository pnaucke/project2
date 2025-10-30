# ----------------------
# SNS Topic for Notifications
# ----------------------
resource "aws_sns_topic" "admin_notifications" {
  name = "admin-notifications"
}

resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.admin_notifications.arn
  protocol  = "email"
  endpoint  = "beheerder@jouwdomein.nl" # <-- vervang met echt e-mailadres
}

# ----------------------
# IAM Role for Lambda (SOAR)
# ----------------------
resource "aws_iam_role" "soar_lambda_role" {
  name = "soar-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "soar_lambda_policy" {
  name = "soar-lambda-policy"
  role = aws_iam_role.soar_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "sns:Publish",
          "ec2:RunInstances",
          "ec2:DescribeInstances",
          "ec2:CreateTags",
          "iam:PassRole"
        ]
        Resource = "*"
      }
    ]
  })
}

# ----------------------
# Lambda Function (SOAR)
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
}

# ----------------------
# CPU Monitoring Alarms
# ----------------------
resource "aws_cloudwatch_metric_alarm" "cpu_high_web" {
  alarm_name          = "CPUHigh-Web"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU usage is above 80% for one or more web servers."
  treat_missing_data  = "notBreaching"

  dimensions = {
    InstanceId = aws_instance.web1.id
  }

  alarm_actions = [
    aws_sns_topic.admin_notifications.arn,
    aws_lambda_function.soar_function.arn
  ]
}

# ----------------------
# Uptime Monitoring (via ALB Health Check)
# ----------------------
data "aws_lb_target_group" "web_tg_data" {
  name = aws_lb_target_group.web_tg.name
}

resource "aws_cloudwatch_metric_alarm" "web1_status_alarm" {
  alarm_name          = "web1-status-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_description   = "Web1 lijkt offline volgens de ALB health check."

  dimensions = {
    TargetGroup  = data.aws_lb_target_group.web_tg_data.arn_suffix
    LoadBalancer = aws_lb.web_lb.arn_suffix
  }

  alarm_actions = [
    aws_sns_topic.admin_notifications.arn,
    aws_lambda_function.soar_function.arn
  ]
  ok_actions = [aws_sns_topic.admin_notifications.arn]
}

resource "aws_cloudwatch_metric_alarm" "web2_status_alarm" {
  alarm_name          = "web2-status-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  treat_missing_data  = "notBreaching"
  alarm_description   = "Web2 lijkt offline volgens de ALB health check."

  dimensions = {
    TargetGroup  = data.aws_lb_target_group.web_tg_data.arn_suffix
    LoadBalancer = aws_lb.web_lb.arn_suffix
  }

  alarm_actions = [
    aws_sns_topic.admin_notifications.arn,
    aws_lambda_function.soar_function.arn
  ]
  ok_actions = [aws_sns_topic.admin_notifications.arn]
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
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", data.aws_lb_target_group.web_tg_data.arn_suffix, "LoadBalancer", aws_lb.web_lb.arn_suffix, { label: "Healthy Hosts" }]
          ],
          period = 60,
          stat   = "Average",
          region = "eu-central-1",
          title  = "Webserver Uptime Status (Up = HealthyHostCount ≥ 1)"
        }
      },
      {
        type = "text",
        x    = 0,
        y    = 7,
        width = 24,
        height = 3,
        properties = {
          markdown = "### 🟢 Status\n- **Web1:** ${aws_cloudwatch_metric_alarm.web1_status_alarm.state_value == "OK" ? "Up" : "Down"}\n- **Web2:** ${aws_cloudwatch_metric_alarm.web2_status_alarm.state_value == "OK" ? "Up" : "Down"}"
        }
      }
    ]
  })
}
