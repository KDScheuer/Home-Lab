# Installing AdGuardExporter

### Creating the Docker compose file
```bash
mkdir -p ~/docker/adguardhome/exporter
vi ~/docker/adguardhome/exporter/docker-compose.yml
```

### Starting the container
```bash
docker compose pull
docker compose up -d
docker compose ps
```

### Configure Firewall to allow DNS ingress
```bash
sudo firewall-cmd --permanent --add-port=9618/tcp
sudo firewall-cmd --reload
```

### Added the following job to the Prometheus YML Config File
```yml
  - job_name: "adguard"
    static_configs:
    - targets: ["192.168.50.200:9618"]
    scrape_interval: 30s
    metrics_path: '/metrics'
```