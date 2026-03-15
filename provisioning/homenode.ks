#version=RHEL9
text
reboot

# Installation source
url --url="https://dl.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/"

# Localization
lang en_US.UTF-8
keyboard --vckeymap=us --xlayouts=us
timezone America/Boise --utc

# Network 
%include /tmp/network.ks

# Security
selinux --enforcing
firewall --enabled --service=ssh

# Disk
zerombr
clearpart --all --initlabel --drives=sda
autopart --type=lvm --fstype=ext4

# Bootloader
bootloader --location=mbr --drive=sda

# Packages
%packages
@^minimal-environment
%end

# Users
rootpw --lock
user --name=ansible --groups=wheel --lock
sshkey --username=ansible "{{ ansible_pub_key }}"

# Services
services --enabled=sshd

%pre
#!/bin/bash
IFACE=$(ip link | awk '/^[0-9]+: e/{print $2}' | head -1 | tr -d ':')
echo "network --bootproto=static --device=$IFACE --ip={{ ip }} --netmask=255.255.255.0 --gateway=192.168.50.1 --nameserver=192.168.50.1 --hostname={{ hostname }}" > /tmp/network.ks
%end

%post
# Passwordless sudo
echo "ansible ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible

# Enforce key-only SSH access
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Set hostname explicitly
hostnamectl set-hostname {{ hostname }}

# Notify provisioning server — triggers Ansible run
curl http://{{ server_ip }}:8080/ansible/{{ ip }}
%end
