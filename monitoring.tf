# ----------------------
# Grafana instance + Prometheus
# ----------------------
locals {
  grafana_user_data = <<-EOT
    #!/bin/bash
    yum update -y
    yum install -y wget tar

    # Install Grafana
    cat <<EOF > /etc/yum.repos.d/grafana.repo
    [grafana]
    name=grafana
    baseurl=https://packages.grafana.com/oss/rpm
    repo_gpgcheck=1
    enabled=1
    gpgcheck=1
    gpgkey=https://packages.grafana.com/gpg.key
    EOF

    yum install -y grafana
    systemctl enable grafana-server
    systemctl start grafana-server

    # Install Prometheus
    cd /tmp
    wget https://github.com/prometheus/prometheus/releases/download/v2.47.0/prometheus-2.47.0.linux-amd64.tar.gz
    tar xvf prometheus-2.47.0.linux-amd64.tar.gz
    cd prometheus-2.47.0.linux-amd64

    mkdir -p /etc/prometheus
    cat <<EOF >/etc/prometheus/prometheus.yml
    global:
      scrape_interval: 15s

    scrape_configs:
      - job_name: 'node_exporter'
        static_configs:
          - targets: ['${aws_instance.web1.private_ip}:9100','${aws_instance.web2.private_ip}:9100']
    EOF

    cp prometheus /usr/local/bin/
    cp promtool /usr/local/bin/

    cat <<EOF >/etc/systemd/system/prometheus.service
    [Unit]
    Description=Prometheus
    Wants=network-online.target
    After=network-online.target

    [Service]
    ExecStart=/usr/local/bin/prometheus \\
      --config.file=/etc/prometheus/prometheus.yml \\
      --storage.tsdb.path=/var/lib/prometheus/ \\
      --web.listen-address=:9090 \\
      --web.enable-lifecycle
    Restart=always

    [Install]
    WantedBy=multi-user.target
    EOF

    mkdir -p /var/lib/prometheus
    systemctl daemon-reload
    systemctl enable --now prometheus
  EOT
}

resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.grafana_subnet.id
  private_ip             = "172.31.4.10"
  vpc_security_group_ids = [aws_security_group.grafana_sg.id]
  key_name               = "Project1"
  user_data              = local.grafana_user_data
  tags = { Name = "grafana" }
}

# ----------------------
# Grafana provider
# ----------------------
terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "~> 1.39"  # kies de gewenste versie
    }
  }
}

provider "grafana" {
  url  = "http://${aws_instance.grafana.private_ip}:3000"
  auth = "admin:SuperSecretGrafana123!"  # pas dit aan naar jouw admin wachtwoord
}


# ----------------------
# Grafana dashboard voor webservers
# ----------------------
resource "grafana_dashboard" "web_monitor" {
  config_json = file("${path.module}/grafana_dashboard_web.json")
}
