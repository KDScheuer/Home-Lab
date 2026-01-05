# Installing Prometheus

![Prometheus](/Assets/Prometheus.png)

### Create Directories for Persistent Data
```bash
sudo mkdir -p /srv/prometheus/{config,data}
sudo chown -R $USER:$USER /srv/prometheus
sudo chown -R 65534:65534 /srv/prometheus/data
ls -la /srv/prometheus
```

### Create Prometheus Configuration
```bash
vi /srv/prometheus/config/prometheus.yml
```

Configured scraping targets and intervals for monitoring various services and exporters.

### Create Docker Compose File
```bash
mkdir -p ~/docker/prometheus
vi ~/docker/prometheus/docker-compose.yml
```

Used the prom/prometheus:latest image with port 9091 mapped to 9090. Configured storage retention time to 15d and connected to proxy network.

### Start Container
```bash
cd ~/docker/prometheus
docker compose pull
docker compose up -d
docker compose ps
```

### Test Prometheus is working
```bash
curl http://localhost:9091/metrics
```

### Allow connection in the firewall to the server
```bash
sudo firewall-cmd --permanent --zone=trusted --add-port=9091/tcp
sudo firewall-cmd --reload
```

Accessed the web interface at port 9091 through Caddy reverse proxy to verify targets and configuration.