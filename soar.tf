resource "aws_iam_role" "soar_lambda_role" {
  name = "soar-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "soar_lambda_policy" {
  role       = aws_iam_role.soar_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_lambda_function" "soar" {
  function_name = "soar-monitor"
  handler       = "soar.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.soar_lambda_role.arn
  filename      = "lambda/soar.zip"
  environment {
    variables = {
      WEB1_INSTANCE_ID = aws_instance.web1.id
      WEB2_INSTANCE_ID = aws_instance.web2.id
    }
  }
}
