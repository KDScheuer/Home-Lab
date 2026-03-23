Yes — Terraform next. Before writing any code I need a few things from you:
First, create a Proxmox API token — Terraform authenticates to Proxmox via an API token rather than your root password. Do this in the Proxmox web UI:

Log into the web UI at https://192.168.50.101:8006
Datacenter → Permissions → API Tokens
Click Add
User: root@pam
Token ID: terraform
Uncheck "Privilege Separation"
Click Add
Copy the token secret immediately — it is only shown once

You'll end up with something like:
Token ID: root@pam!terraform
Secret:   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

On your Synology create a folder at:
/volume1/networkShare/terraform-state

Q: Which Proxmox Terraform provider do you want to use? bpg/proxmox is the current recommended provider but most blog posts use Telmate.
A: bpg/proxmox (actively maintained, recommended)

Q: VM IDs — do you want to explicitly set them to match your IP scheme?
A: Use VM ID matching last octet of IP (131, 111, 112 etc)

