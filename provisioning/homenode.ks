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
user --name=ansible --groups=wheel --iscrypted --password='$6$homelab$GOG4nTpUJFoRc/ZmIRWclEmfVMEwQkBfkR7Dry2HZNCm7OvsCENawrjIIZbEgQp6E.DJSiS.rHtUwMcLkL8YQ/'

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

# Enable password auth so Ansible can connect on first run
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart sshd

# Set hostname explicitly
hostnamectl set-hostname {{ hostname }}

# Notify HTTP Ready for Ansible
curl http://192.168.50.4:8080/ansible/{{ ip }}
%end
