# ----------------------
# Variable for Grafana admin password
# ----------------------
variable "grafana_admin_pw" {
  description = "Grafana admin password"
  type        = string
  sensitive   = true
}

# ----------------------
# Grafana + Prometheus instance
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

    # Set Grafana admin password from environment variable
    sudo grafana-cli admin reset-admin-password ${GRAFANA_ADMIN_PW}

    # Provision datasource
    mkdir -p /etc/grafana/provisioning/datasources
    cat <<EOF >/etc/grafana/provisioning/datasources/datasource.yml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
EOF

    # Provision dashboards
    mkdir -p /etc/grafana/provisioning/dashboards
    mkdir -p /var/lib/grafana/dashboards
    cat <<EOF >/etc/grafana/provisioning/dashboards/dashboard.yml
apiVersion: 1
providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    options:
      path: /var/lib/grafana/dashboards
EOF

    # Copy dashboard JSON
    cp /tmp/grafana_dashboard_web.json /var/lib/grafana/dashboards/grafana_dashboard_web.json

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

    # Prometheus service
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

# ----------------------
# Grafana instance
# ----------------------
resource "aws_instance" "grafana" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.grafana_subnet.id
  private_ip             = "172.31.4.10"
  vpc_security_group_ids = [aws_security_group.grafana_sg.id]
  key_name               = "Project1"
  user_data              = local.grafana_user_data
  tags = { Name = "grafana" }

  # Upload dashboard JSON so user_data can copy it
  provisioner "file" {
    source      = "grafana_dashboard_web.json"
    destination = "/tmp/grafana_dashboard_web.json"
  }
}

