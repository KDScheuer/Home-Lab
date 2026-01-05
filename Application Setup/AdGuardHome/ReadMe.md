# Installing AdGuard Home

![AdGuard Home](/Assets/AdGuardHome.png)

### Create Directories for Persistent Data
```bash
sudo mkdir -p /srv/adguardhome/{work,conf}
sudo chown -R $USER:$USER /srv/adguardhome
ls -la /srv/adguardhome
```

### Creating the Docker compose file
```bash
mkdir -p ~/docker/adguardhome
vi ~/docker/adguardhome/docker-compose.yml
```

Used the adguard/adguardhome:latest image with ports 53 (TCP/UDP) for DNS and 853 (TCP/UDP) for DNS-over-TLS. Connected to the external proxy network for Caddy integration.

### Starting the container
```bash
docker compose pull
docker compose up -d
docker compose ps
```

### Configure Firewall to allow DNS ingress
```bash
sudo firewall-cmd --permanent --add-port=53/tcp
sudo firewall-cmd --permanent --add-port=53/udp
sudo firewall-cmd --permanent --add-port=853/tcp
sudo firewall-cmd --reload
```

After deployment, accessed the web interface through Caddy reverse proxy to complete the initial setup and configuration.
