# ----------------------
# Security Groups
# ----------------------
resource "aws_security_group" "web_sg" {
  name   = "web-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name   = "db-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "soar_sg" {
  name   = "soar-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "lb_sg" {
  name   = "lb-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Webserver Rules
resource "aws_security_group_rule" "web_from_lb_http" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.web_sg.id
  source_security_group_id = aws_security_group.lb_sg.id
}

resource "aws_security_group_rule" "web_ssh_from_admins" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  security_group_id = aws_security_group.web_sg.id
  cidr_blocks       = ["82.170.150.87/32", "145.93.76.166/32"]
}

# DB Rules
resource "aws_security_group_rule" "db_from_web" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db_sg.id
  source_security_group_id = aws_security_group.web_sg.id
}
