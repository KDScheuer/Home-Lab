



When installing Rocky pass in 
`inst.ks=http://192.168.50.4:8080/ks/192.168.50.101/k3s-node1`
as a boot param to pull the kickstarter file

Kickstarter file will handle OS install and getting host to the point where ansible can take over


> **Note:** URL-encode the boot parameter to avoid issues with special characters such as `&`.


### Starting the provisioning environment

```bash
curl -O https://raw.githubusercontent.com/KDScheuer/Home-Lab/v2/provisioning/bootstrap.sh
chmod +x bootstrap.sh
./bootstrap.sh
```

`bootstrap.sh` installs dependencies, clones the repo, configures the vault password and SSH key, and starts the HTTP server. One command to go from a bare laptop to a fully operational provisioning environment.

### Files

| File | Purpose |
|---|---|
| `provisioning/bootstrap.sh` | Sets up provisioning environment from scratch |
| `provisioning/http-server.py` | Dynamic Kickstart HTTP server with Ansible trigger |
| `provisioning/homenode.ks` | Kickstart template with `{{ ip }}` and `{{ hostname }}` substitution |

> **Note:** The Kickstart template uses `%pre` to dynamically discover the active network interface at install time, making provisioning hardware-agnostic without requiring interface names to be known ahead of time.

---

## Setting up the provisioning server

### Prerequisites

Install Rocky Linux 9 on a VM or bare metal machine with a static IP on your LAN. 
Bridged networking is required so provisioned nodes can reach the server during install.

### SSH keys

The provisioning server needs an SSH key pair before running the bootstrap script. 
Either copy an existing private key or generate a new one:
```bash
ssh-keygen -t ed25519 -C "homelab-ansible" -f ~/.ssh/ansible -N ""
```

The public key at `~/.ssh/ansible.pub` is what gets deployed to provisioned nodes 
by Ansible. Make sure this matches the value in `ansible/inventory/group_vars/all.yml` 
before pointing any nodes at this server.

### Bootstrap

Once your key is in place, download and run the bootstrap script:
```bash
curl -O https://raw.githubusercontent.com/KDScheuer/Home-Lab/v2/provisioning/bootstrap.sh
chmod +x bootstrap.sh
./bootstrap.sh
```

> **Note:** Do not pipe directly to bash (`curl | bash`). The script prompts interactively for passwords and will fail if stdin is the pipe.

This will:
- Update system packages
- Install git, python3, ansible, tmux
- Clone the v2 branch of this repo
- Prompt for the Ansible user password and configure vault
- Hash the password and inject it into the kickstart template
- Open port 8080 in firewalld
- Start the kickstart HTTP server in a tmux session

### After bootstrap

Attach to the kickstart server session to verify it is running:
```bash
tmux attach -t kickstart_server
```

The server is ready when you see it listening on port 8080. Nodes can now be 
provisioned by booting the Rocky Linux 9 ISO and entering the kickstart URL 
at the boot prompt:
```
inst.ks=http://<provisioning-server-ip>:8080/ks/<node-ip>/<hostname>
```