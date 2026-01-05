# Installing Grafana

![Grafana](/Assets/Grafana.png)

### Create Directories for Persistent Data
```bash
sudo mkdir -p /srv/grafana/{data,logs,plugins}
sudo chown -R 472:472 /srv/grafana
ls -la /srv/grafana
```

### Create Environment File
```bash
cd ~/docker/grafana
cp .env.example .env
vi .env
```

Set the GF_SECURITY_ADMIN_PASSWORD environment variable for the admin account.

### Create Docker Compose File
```bash
mkdir -p ~/docker/grafana
vi ~/docker/grafana/docker-compose.yml
```

Used the latest Grafana image with port 3000 exposed, environment variables from .env file, and connected to the proxy network. Disabled user sign-up.

### Start Container
```bash
cd ~/docker/grafana
docker compose pull
docker compose up -d
docker compose ps
```

### Allow port 3000 through firewall
```bash
sudo firewall-cmd --permanent --zone=trusted --add-port=3000/tcp
sudo firewall-cmd --reload
```

### Test Grafana is working
```bash
curl http://localhost:3000
```

Accessed the web interface through Caddy reverse proxy and configured Prometheus as the data source.
