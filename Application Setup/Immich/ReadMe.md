# Installing Immich

![Immich](/Assets/Immich.png)

### Creating Persistent Directories for Database, Cache, etc.
```bash
sudo mkdir -p /srv/immich/{photos,postgres,redis}
sudo chown -R $USER:$USER /srv/immich
ls -la /srv/immich/
```

### Download Docker Compose and Environment Files
```bash
mkdir -p ~/docker/immich
cd ~/docker/immich
sudo dnf install wget -y
wget -O docker-compose.yml https://github.com/immich-app/immich/releases/latest/download/docker-compose.yml
wget -O .env https://github.com/immich-app/immich/releases/latest/download/example.env
```

### Modify the .env file with desired values
```bash
vi .env
```

Configured the environment variables for upload location, database settings, and other Immich-specific configurations. Used the official Immich docker-compose with immich-server, immich-machine-learning, redis, and postgres services.

### Start the Containers
```bash
docker compose pull
docker compose up -d
docker compose ps
```

Accessed the web interface through Caddy reverse proxy to complete user registration and initial setup.