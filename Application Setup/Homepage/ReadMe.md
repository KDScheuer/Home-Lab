# Homepage Setup

![Homepage](/Assets/homepage.png)

This is a simple homepage / landing page for ease of access to all deployed applications within my home lab, as well as some links to external sites that are often used.

The application is a simple nginx container that serves the `index.html` and `styles.css` files.

### Create Docker Compose File
```bash
mkdir -p ~/docker/homepage
cd ~/docker/homepage
vi docker-compose.yml
```

Used nginx:alpine image with volume mount to serve static files from /srv/homepage. Connected to proxy network for Caddy integration.

### Making Directories to store webpage files
```bash
sudo mkdir -p /srv/homepage
sudo chown -R $USER:$USER /srv/homepage
touch /srv/homepage/index.html /srv/homepage/styles.css
ls -la /srv/homepage
```

### Bringing Containers Up
```bash
docker compose pull
docker compose up -d
docker compose ps
```

Edited the index.html and styles.css files to create a custom homepage with links to all the home lab services.