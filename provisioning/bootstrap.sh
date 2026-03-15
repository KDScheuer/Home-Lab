#!/bin/bash
set -e
echo "Configuring provisioning server"

# Update and upgrade system packages
echo "[+] Updating system packages, this may take a while..."
sudo dnf update -y > /dev/null && sudo dnf upgrade -y > /dev/null

# Install necessary dependencies (ansible requires EPEL on Rocky Linux 9)
echo "[+] Installing dependencies"
sudo dnf install -y epel-release > /dev/null
sudo dnf install -y git python3 ansible tmux > /dev/null

# Clone or update the homelab repository
echo "[+] Syncing repo"
if [ -d ~/homelab ]; then
    echo "[+] Repo already exists, pulling latest changes"
    git -C ~/homelab pull > /dev/null
else
    git clone -b v2 https://github.com/kdscheuer/Home-Lab.git ~/homelab > /dev/null
fi

# Prompt for credentials — skip if already configured unless user requests reconfiguration
RECONFIGURE=false
if [ -f ~/.vault_pass ]; then
    read -p "[?] Credentials already configured. Reconfigure? [y/N]: " RESP
    [[ "$RESP" =~ ^[Yy]$ ]] && RECONFIGURE=true || echo "[+] Keeping existing credentials"
else
    RECONFIGURE=true
fi

if [ "$RECONFIGURE" = true ]; then
    echo "[+] Configuring passwords"
    read -s -p "Enter ansible user password: " ANSIBLE_PASS
    echo
    read -s -p "Enter vault encryption password: " VAULT_PASS
    echo
    echo "$VAULT_PASS" > ~/.vault_pass
    chmod 600 ~/.vault_pass

    # Hash the Ansible user password and update the kickstart file
    HASHED=$(openssl passwd -6 -salt homelab "$ANSIBLE_PASS")
    sed -i "s|password='.*'|password='$HASHED'|" ~/homelab/provisioning/homenode.ks

    # Encrypt the Ansible password and store it in the vault file.
    # Remove any existing vault_ansible_password entry first to prevent duplicates on re-runs.
    if [ -f ~/homelab/ansible/vault.yml ] && grep -q 'vault_ansible_password' ~/homelab/ansible/vault.yml; then
        echo "[+] Replacing existing vault_ansible_password entry"
        python3 - <<'EOF'
import re, os
path = os.path.expanduser("~/homelab/ansible/vault.yml")
with open(path) as f:
    content = f.read()
# Remove the vault_ansible_password block — the key line plus all indented continuation lines
content = re.sub(r'^vault_ansible_password:.*?(?=^\S|\Z)', '', content, flags=re.MULTILINE | re.DOTALL)
with open(path, 'w') as f:
    f.write(content)
EOF
    fi
    ansible-vault encrypt_string "$ANSIBLE_PASS" \
        --name 'vault_ansible_password' \
        --vault-password-file ~/.vault_pass \
        >> ~/homelab/ansible/vault.yml
fi

# Open port 8080 for the kickstart server — skip reload if already open
echo "[+] Checking firewall for port 8080"
if sudo firewall-cmd --query-port=8080/tcp --permanent > /dev/null 2>&1; then
    echo "[+] Port 8080 already open"
else
    sudo firewall-cmd --add-port=8080/tcp --permanent > /dev/null
    sudo firewall-cmd --reload > /dev/null
    echo "[+] Port 8080 opened"
fi

# Check for Ansible SSH key and warn if not found
echo "[+] Checking for Ansible SSH key"
if [ ! -f ~/.ssh/ansible ]; then
    echo -e "\e[33m[!] No SSH key found at ~/.ssh/ansible\e[0m"
    echo -e "\e[33m[!] Copy your private key to ~/.ssh/ansible before pointing nodes at this server\e[0m"
    echo -e "\e[33m[!] Ansible will fail to connect to provisioned nodes without it\e[0m"
else
    echo "[+] Ansible SSH key found"
    echo "[+] Public key that will be deployed to nodes:"
    cat ~/.ssh/ansible.pub
fi

# Start the kickstart server in a tmux session
echo "[+] Starting kickstart server"
cd ~/homelab/provisioning
tmux has-session -t kickstart_server 2>/dev/null \
    && echo "[!] kickstart_server session already running" \
    || tmux new-session -d -s kickstart_server "python3 http-server.py"
echo "[+] Attach with: tmux attach -t kickstart_server"

echo "[+] Provisioning server setup complete"