# Installing Mealie

![Mealie](/Assets/Mealie.png)

### Creating Dirs for persistent data
```bash
sudo mkdir -p /srv/mealie/{data,postgres}
sudo chown -R $USER:$USER /srv/mealie
ls -la /srv/mealie
```

### Creating Environment File
```bash
mkdir -p ~/docker/mealie
cp .env.example .env
vi ~/docker/mealie/.env
```

Configured environment variables for timezone, PostgreSQL credentials, and base URL for the application.

### Create docker compose file
```bash
vi ~/docker/mealie/docker-compose.yml
```

Used the latest Mealie image with PostgreSQL database. Connected both services to the proxy network for Caddy integration. Configured environment variables from the .env file.

### Start Mealie with Docker Compose
```bash
docker compose pull
docker compose up -d
docker compose ps
```

Accessed the web interface through Caddy reverse proxy to complete user registration and initial setup.