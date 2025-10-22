resource "aws_security_group" "soar_sg" {
  name   = "${var.project_name}-soar-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.db_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DynamoDB table voor SOAR logging
resource "aws_dynamodb_table" "soar_logs" {
  name         = "${var.project_name}-soar-logs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "Event"

  attribute {
    name = "Event"
    type = "S"
  }
}

# IAM role voor Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-soar-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ec2_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_sns_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

# Lambda functie (SOAR)
resource "aws_lambda_function" "soar_lambda" {
  function_name = "${var.project_name}-soar-lambda"
  handler       = "lambda_function.handler"
  runtime       = "python3.10"
  role          = aws_iam_role.lambda_role.arn
  filename      = "lambda_function_payload.zip" # zip bestand moet lokaal aanwezig zijn

  vpc_config {
    subnet_ids         = [aws_subnet.soar.id]
    security_group_ids = [aws_security_group.soar_sg.id]
  }

  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.soar_logs.name
      PROJECT_NAME   = var.project_name
    }
  }
}
