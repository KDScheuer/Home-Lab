# Installing Caddy

### Create Directories
```bash
sudo mkdir -p /srv/caddy/{data,config,sites}
sudo chown -R $USER:$USER /srv/caddy
ls -la /srv/caddy
```

### Creating CaddyFile
```bash
vi /srv/caddy/config/Caddyfile
```

Configured reverse proxy rules for all home lab services with automatic HTTPS certificate generation and renewal.

### Creating Docker Compose File
```bash
mkdir -p ~/docker/caddy
vi ~/docker/caddy/docker-compose.yml
```

Used the latest Caddy image with ports 80 and 443 exposed. Mounted the Caddyfile, data directory for certificates, and /srv/certs as read-only. Connected to the external proxy network.

### Starting the container
```bash
docker compose pull
docker compose up -d
docker compose ps
```

### Configure Firewall to allow HTTP and HTTPS Traffic
```bash
sudo firewall-cmd --permanent --add-port=80/tcp
sudo firewall-cmd --permanent --add-port=443/tcp
sudo firewall-cmd --reload
```

Caddy automatically handles SSL certificate generation and renewal for all configured domains in the Caddyfile.