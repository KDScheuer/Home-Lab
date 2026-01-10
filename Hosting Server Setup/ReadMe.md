# Hosting Server Configurations

### Setting Static IP Address and Public DNS Servers
```bash
sudo nmcli connection add type ethernet \
    ifname enp2s0 \
    con-name enp2s0-static \
    ipv4.mthod manual \
    ipv4.addresses 192.168.50.200/24 \
    ipv4.gateway 192.168.50.1 \
    ipv4.dns "1.1.1.1 8.8.8.8"
```

## Configure NTP
```bash
sudo dnf install -y chrony
sudo systemctl enable --now chronyd
sudo systemctl status chronyd
sudo chronyc makestep
```

### Installing Required Packages
```bash
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
```

### Setting up Dedicated Drive and Mount Point for Applications
- Wiping the Drive of all partitions and data as this was used in the past for something else
```bash
sudo wipefs -a /dev/sda
```
- Creating partition table, partition, and formatting the parition
```bash
sudo parted /dev/sda --script mklabel gpt
sudo parted /dev/sda --script mkpart primary xfs 0% 100%
sudo mkfs.xfs -f /dev/sda1
```
- Creating the Mount Point for the New Drive
```bash
sudo mkdir -p /srv
sudo chown $USER:$USER /srv
```
- Modifing `/etc/fstab` to mount the new drive to this mount point persistently

*Getting UUID of new partition to create fstab entry*
```bash
sudo blkid /dev/sda1
sudo vi /etc/fstab
```
*New Line in `/etc/fstab`*
```bash
UUID=3ccd63ec-133c-4ce9-9c41-303759d82267  /srv  xfs  defaults,noatime  0  2
```
*Reloading Daemon and Mounting the drive*
```bash
sudo systemctl daemon-reload
sudo mount -a
```

### Creating Docker Compose File Directory Structure
```bash
mkdir -p \
    ~/docker/immich \
    ~/docker/mealie \
    ~/docker/jellyfin \
    ~/docker/homepage \
    ~/docker/caddy \
    ~/docker/adguardhome \
    ~/docker/bitwarden \
    ~/docker/grafana \
    ~/docker/prometheus
```

### Creating Directory Structure for persistent volumes in containers
```bash
mkdir -p \
    /srv/immich \
    /srv/mealie \
    /srv/jellyfin \
    /srv/caddy \
    /srv/homepage \
    /srv/adguardhome \
    /srv/vaultwarden \
    /srv/grafana \
    /srv/prometheus \
```

### Starting Docker Daemon
```bash
sudo usermod -aG docker $USER
newgrp docker
sudo systemctl enable --now docker
```

### Creating a Docker Network
```bash
docker network create proxy
```

### SSL Certificate Configuration
*Install Certbot packages*
```bash
sudo dnf install -y epel-release
sudo dnf install -y certbot python3-certbot-dns-route53
```

*Create Directories for Certificate*
```bash
sudo mkdir -p /root/.aws
sudo chmod 700 /root/.aws
```

*Configure AWS Credentials*
```bash
sudo vi /root/.aws/credentials
```
```bash
[default]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
```
```bash
sudo chmod 600 /root/.aws/credentials
```

*Issue the cert*
```bash
sudo certbot certonly \
  --dns-route53 \
  -d home.kds-dev.com \
  -d mealie.kds-dev.com \
  -d adguard.kds-dev.com \
  -d immich.kds-dev.com \
  -d prometheus.kds-dev.com \
  -d grafana.kds-dev.com \
  -d jellyfin.kds-dev.com \
  -d caddy.kds-dev.com \
  -d vaultwarden.kds-dev.com \
  --agree-tos \
  --email kdscheuer97@gmail.com \
  --non-interactive
```

*Verify Cert Issued*
```bash
sudo ls -la /etc/letsencrypt/live/home.kds-dev.com/
```

*Expose Cert to Containers*
```bash
sudo mkdir -p /srv/certs/home.kds-dev.com
sudo chown $USER:$USER -R /srv/certs/home.kds-dev.com
sudo sh -c 'cp -L /etc/letsencrypt/live/home.kds-dev.com-0001/* /srv/certs/home.kds-dev.com/'
sudo chown kscheuer:kscheuer \
    /srv/certs/home.kds-dev.com/cert.pem \
    /srv/certs/home.kds-dev.com/chain.pem \
    /srv/certs/home.kds-dev.com/fullchain.pem \
    /srv/certs/home.kds-dev.com/privkey.pem \
    /srv/certs/home.kds-dev.com/README
```

## SSH Setup
### Generating Keypair
```bash
ssh-keygen -t ed25519 -C "kdscheuer97@gmail.com"
# Saving as: /home/kscheuer/.ssh/homelab
```
### Creating Authorized Key File
```bash
cd ~/.ssh
chmod 700 ~/.ssh
cat homelab.pub >> authorized_keys
chmod 600 authorized_keys
chown -R kscheuer:kscheuer ~/.ssh
```

### Allowing Public Key Authentication
```bash
vi /etc/ssh/sshd_config
```
```bash
PubkeyAuthentication yes
```

### Verify There are no SELinux issues
```bash
restorecon -R -v ~/.ssh
```

### Testing SSH Using Public key
```bash
ssh -i homelab kscheuer@192.168.50.200
```

### Adding SSH Config on Client for Easy SSH Access
```sh
notepad $HOME\.ssh\config
```
```sh
Host homelab
    HostName 192.168.50.200
    User kscheuer
    IdentityFile C:\Users\kdsch\homelab
```

### Testing Access with new config
```bash
ssh homelab
```

### Removing Password Auth from SSH Access
```bash
vi /etc/ssh/sshd_config
```
```bash
PasswordAuthentication no
```
```bash
sudo systemctl reload sshd
```

### Testing Password SSH no longer works
```sh
ssh kscheuer@192.168.50.200
```
