# Installing FileBrowser

![FileBrowser](/Assets/Filebrowser.png)

### Create Directories for Persistent Data
```bash
sudo mkdir -p /srv/filebrowser/{config,data}
sudo chown -R $USER:$USER /srv/filebrowser
ls -la /srv/filebrowser
```

### Creating the Docker compose file
```bash
mkdir -p ~/docker/filebrowser
vi ~/docker/filebrowser/docker-compose.yml
```

Set up FileBrowser with appropriate volume mounts and connected to the proxy network for Caddy integration.

### Starting the container
```bash
docker compose pull
docker compose up -d
docker compose ps
```

### Get Default Random Admin Password
```bash
docker logs filebrowser
```

Logged into the web interface with the default admin credentials from the container logs and changed the password immediately.