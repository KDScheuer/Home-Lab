# Server Configs
  1.  Install Required Packages (nfs-utils, docker, docker-compose, epel-release, etc)
  2.  Timezone and NTP Settings
  3.  Hostname Settings
  4.  Static IP Setting
  5.  DNS Settings
  6.  SELinux Enabled
  7.  Create Homelab User with Home Dir and sudo permissions
  8.  Ensure Authorized_Keys file exists
  9.  Populate Public Key into file
  10. Restore SELinux context on .ssh directory restorecon -R -v /home/{{ homelab_user }}/.ssh
  11. Disable SSH as root
  12. Enable Public Key Auth for SSH
  13. Disable Password Auth for SSH
  14. Create Mount Dir for NAS
  15. Mount NAS as NFS via fstab entry # mount options to look into nfs rw,hard,nointr,rsize=131072,wsize=131072,timeo=600,retrans=3
  16. Firewall Rules and Restart
  17. /etc/hosts entries for all k3s nodes for reliable dns resolition
  18. Kernel modules and sysctl settings — k3s needs br_netfilter and overlay loaded, plus net.bridge.bridge-nf-call-iptables=1 and ip_forward=1
  19. setsebool -P virt_use_nfs 1 #sets nfs for selinux k3s permissions
