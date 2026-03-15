



When installing Rocky pass in 
`inst.ks=http://192.168.50.4:8080/ks/192.168.1.101/node1`
as a boot param to pull the kickstarter file

Kickstarter file will handle OS install and getting host to the point where ansible can take over


> **Note:** URL-encode the boot parameter to avoid issues with special characters such as `&`.


### Starting the provisioning environment

```bash
curl -O https://raw.githubusercontent.com/kdscheuer/homelab/v2/provisioning/bootstrap.sh
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