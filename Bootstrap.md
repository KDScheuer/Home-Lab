Manually Installed Proxmox on each server

Pulled all servers into cluster

Created Ansible User with Keypair on each server

    # Proxmox ships with enterprise repos enabled which require a subscription key.
    # Disable them and add the no-subscription repo before running apt.
    echo '' > /etc/apt/sources.list.d/pve-enterprise.sources
    echo '' > /etc/apt/sources.list.d/ceph.sources
    echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" \
      > /etc/apt/sources.list.d/pve-nosub.list

    # Install sudo (not included in Proxmox by default)
    apt update && apt install -y sudo

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

    # Paste the ansible public key (~/.ssh/ansible.pub from the management machine)
    echo "YOUR_ANSIBLE_PUBLIC_KEY" >> /home/ansible/.ssh/authorized_keys
