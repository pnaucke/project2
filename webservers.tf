locals {
  user_data = <<-EOT
    #!/bin/bash
    yum update -y
    amazon-linux-extras enable nginx1
    yum install -y nginx mysql wget tar

    systemctl start nginx
    systemctl enable nginx

    MY_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

    DB_TEST="OK"
    mysql -h ${aws_db_instance.db.address} -uadmin -pSuperSecret123! -e "SELECT 1;" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      DB_TEST="FAILED"
    fi

    echo "<h1>Welkom bij mijn website!</h1>" > /usr/share/nginx/html/index.html
    echo "<p>Deze webserver IP: $MY_IP</p>" >> /usr/share/nginx/html/index.html
    echo "<p>Database verbindingstest: $DB_TEST</p>" >> /usr/share/nginx/html/index.html

    echo "DB_HOST=${aws_db_instance.db.address}" >> /etc/environment
    echo "DB_PORT=${aws_db_instance.db.port}" >> /etc/environment
    echo "DB_USER=admin" >> /etc/environment
    echo "DB_PASS=SuperSecret123!" >> /etc/environment
    echo "DB_NAME=myappdb" >> /etc/environment
  EOT
}

resource "aws_instance" "web1" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.web1_subnet.id
  private_ip             = "172.31.1.10"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = "Project1"
  user_data              = local.user_data
  tags = { Name = "web1" }
}

resource "aws_instance" "web2" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.web2_subnet.id
  private_ip             = "172.31.11.10"
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = "Project1"
  user_data              = local.user_data
  tags = { Name = "web2" }
}
