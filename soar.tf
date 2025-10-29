# SOAR Lambda
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

resource "aws_iam_role_policy_attachment" "soar_lambda_policy" {
  role       = aws_iam_role.soar_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

resource "aws_lambda_function" "soar" {
  function_name = "soar-monitor"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  role          = aws_iam_role.soar_lambda_role.arn
  filename      = "lambda/soar.zip" # Lambda code zip
}
