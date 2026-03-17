#!/bin/bash
set -e
echo "Configuring provisioning server"

# -- System packages --
echo "[+] Updating system packages, this may take a while..."
sudo dnf update -y && sudo dnf upgrade -y

echo "[+] Installing dependencies"
sudo dnf install -y epel-release
sudo dnf install -y git python3 ansible tmux

# -- Repo --
echo "[+] Syncing repo"
if [ -d ~/homelab ]; then
    echo "[+] Repo already exists, pulling latest changes"
    git -C ~/homelab pull > /dev/null
else
    git clone -b v2 https://github.com/kdscheuer/Home-Lab.git ~/homelab > /dev/null
fi

# -- Ansible collections --
echo "[+] Installing required Ansible collections"
ansible-galaxy collection install -r ~/homelab/ansible/requirements.yml --upgrade > /dev/null

# -- SSH key (required) --
# The public key is injected into every provisioned node via the kickstart sshkey directive.
# Ansible then connects exclusively via this key — no password auth required.
echo "[+] Checking for Ansible SSH key"
if [ ! -f ~/.ssh/ansible ]; then
    echo -e "\e[31m[!] No SSH key found at ~/.ssh/ansible — cannot continue.\e[0m"
    echo -e "\e[31m[!] Generate one with: ssh-keygen -t ed25519 -C \"homelab-ansible\" -f ~/.ssh/ansible -N \"\"\e[0m"
    echo -e "\e[31m[!] Or copy the existing key to ~/.ssh/ansible\e[0m"
    exit 1
fi
PUBKEY=$(cat ~/.ssh/ansible.pub)
echo "[+] SSH public key loaded"

# -- Detect provisioning server IP --
SERVER_IP=$(ip route get 1 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1); exit}')
echo "[+] Provisioning server IP: $SERVER_IP"

# -- Render kickstart template --
# Substitutes server-specific values into the kickstart template. The template is reset
# to its placeholder state on each git pull, so these seds always run against a clean file.
KS_FILE=~/homelab/provisioning/homenode.ks
sed -i "s|{{ server_ip }}|$SERVER_IP|" "$KS_FILE"
sed -i "s|{{ ansible_pub_key }}|$PUBKEY|" "$KS_FILE"
echo "[+] Kickstart rendered for server $SERVER_IP"

# -- Firewall --
echo "[+] Checking firewall for port 8080"
if sudo firewall-cmd --query-port=8080/tcp --permanent > /dev/null 2>&1; then
    echo "[+] Port 8080 already open"
else
    sudo firewall-cmd --add-port=8080/tcp --permanent > /dev/null
    sudo firewall-cmd --reload > /dev/null
    echo "[+] Port 8080 opened"
fi

# -- Start kickstart server --
echo "[+] Starting kickstart server"
cd ~/homelab/provisioning
if tmux has-session -t kickstart_server 2>/dev/null; then
    echo "[!] Restarting existing kickstart_server session"
    tmux kill-session -t kickstart_server
fi
tmux new-session -d -s kickstart_server "python3 http-server.py"
echo "[+] Attach with: tmux attach -t kickstart_server"

echo "[+] Provisioning server setup complete"