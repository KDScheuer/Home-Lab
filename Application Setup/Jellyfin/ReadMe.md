# Installing Jellyfin

![Jellyfin](/Assets/jellyfin.png)

### Create Directories for Persistent Data
```bash
sudo mkdir -p /srv/jellyfin/{config,cache,media}
sudo chown -R $USER:$USER /srv/jellyfin
ls -la /srv/jellyfin
```

### Creating the Docker compose file
```bash
mkdir -p ~/docker/jellyfin
vi ~/docker/jellyfin/docker-compose.yml
```

Used the jellyfin/jellyfin:latest image with ports 8096 and 7359 exposed. Configured timezone and ffmpeg path. Connected to the proxy network for Caddy integration.

### Starting the container
```bash
docker compose pull
docker compose up -d
docker compose ps
```

Accessed the web interface at port 8096 to complete the initial Jellyfin setup wizard and configured media libraries for the mounted directories.

