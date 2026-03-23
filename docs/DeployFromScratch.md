# Deploying from Scratch

## Setting up WSL 
Create or Copy in Ansible user keypair
install ansible and terraform
follow WSL Setup.md guide for assistance

## Preparing 3 hosting servers
1. Manually Install Proxmox on each of the hosting servers

2. Pull all proxmox servers into a cluster

3. Ensure Virtualization is enabled on hosting servers in BIOS

4. Install sudo on hosting servers for ansible to use. This requires that we use the no subscrition repo and disable the enterprise repos.
```bash
# Remove Enterprise Repos
echo '' > /etc/apt/sources.list.d/pve-enterprise.sources
echo '' > /etc/apt/sources.list.d/ceph.sources

# Add non subscription repo
echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" > /etc/apt/sources.list.d/pve-nosub.list

# Install sudo (not included in Proxmox by default)
apt update && apt install -y sudo
```

5. Create Ansible User on all 3 hosting servers with the below commands
```bash
# Create ansible user
useradd -m -s /bin/bash ansible

# Passwordless sudo
echo "ansible ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible

# Set up SSH key
mkdir -p /home/ansible/.ssh
chmod 700 /home/ansible/.ssh
touch /home/ansible/.ssh/authorized_keys
chmod 600 /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible/.ssh

# Paste the ansible public key
echo "YOUR_ANSIBLE_PUBLIC_KEY" >> /home/ansible/.ssh/authorized_keys
```

6. Create API Key for Terraform use

## Set Proxmox Configurations
Run the following playbook
`ansible/playbooks/proxmox_config.yml`

## Create VM Template
Use the following guide to create the Rocky 9 Template ![Create Template]("ansible/vm-template/rockyTemplate.md")


## Run Terraform to Create all the machines


## Create k3s cluster secret


## Run the remainder of the playbooks in the following order


    
