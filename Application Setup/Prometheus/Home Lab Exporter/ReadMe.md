# Exporter Install

### Install Python Dependencies
```bash
sudo dnf install python3 python3-pip -y
sudo pip install psutil requests speedtest-cli
```

### Create Dedicated User
```bash
sudo useradd --system --shell /bin/false --home /opt/homelab_exporter homelab_exporter
```

### Set Up Application Directory
```bash
sudo mkdir -p /opt/homelab_exporter
sudo chown homelab_exporter:homelab_exporter /opt/homelab_exporter
sudo touch /opt/homelab_exporter/homelab_exporter.py
sudo chown homelab_exporter:homelab_exporter /opt/homelab_exporter/homelab_exporter.py
sudo chmod +x /opt/homelab_exporter/homelab_exporter.py
```
Copy Script into `/opt/homelab_exporter/homelab_exporter.py`
```bash
sudo vi /opt/homelab_exporter/homelab_exporter.py
```

### Create Systemd Service File
```bash
sudo vi /etc/systemd/system/homelab_exporter.service
```
Add the below content
```conf
[Unit]
Description=Home Lab Prometheus Exporter
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=homelab_exporter
Group=homelab_exporter
WorkingDirectory=/opt/homelab_exporter
ExecStart=/usr/bin/python3 /opt/homelab_exporter/homelab_exporter.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=homelab_exporter

# Security settings
NoNewPrivileges=false
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/log

# Network settings
PrivateNetwork=false

# Allow access to Docker socket if needed
SupplementaryGroups=docker

[Install]
WantedBy=multi-user.target
```

### Set up logging directory permissions
```bash
sudo mkdir -p /var/log
sudo chown root:adm /var/log
sudo chmod 755 /var/log
sudo usermod -a -G adm homelab_exporter
```

### Allow user to run docker commands
```bash
sudo usermod -a -G docker homelab_exporter
```

### Allow user to run du command with sudo permissions
```bash
echo "homelab_exporter ALL=(ALL) NOPASSWD: /usr/bin/du" | sudo tee /etc/sudoers.d/homelab_exporter
sudo chmod 440 /etc/sudoers.d/homelab_exporter
```

### Enable / Start Service
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now homelab_exporter
sudo systemctl status homelab_exporter
```

### Allow connetion in the firewall to the server
```bash
# Allow port 9090 through firewall
sudo firewall-cmd --permanent --zone=trusted --add-port=9090/tcp
sudo firewall-cmd --reload
```

### Ensure SELinux does not block connections to this port
```bash
sudo dnf install policycoreutils-python-utils -y
sudo semanage port -a -t http_port_t -p tcp 9090
```

### Test Server is working
```bash
curl http://localhost:9090/metrics
```


