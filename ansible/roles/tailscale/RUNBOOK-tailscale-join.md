# Runbook: Join ts1 to Tailscale Tailnet

## Overview

Ansible installs and starts the Tailscale daemon on ts1 but does not
join the tailnet automatically. Joining is a deliberate manual step
because Taillock (device approval) is enabled — automating around it
would undermine its purpose.

This runbook is run once after the Ansible tailscale playbook completes
successfully. It does not need to be repeated unless ts1 is rebuilt
from scratch.

---

## Prerequisites

- ts1 VM is running and reachable at 192.168.50.131
- Ansible tailscale.yml playbook has been run successfully
- tailscaled service is running on ts1
- Access to the Tailscale admin console (login.tailscale.com/admin)

---

## Steps

### 1. SSH into ts1

```bash
ssh ansible@192.168.50.131
```

### 2. Verify tailscaled is running

```bash
sudo systemctl status tailscaled
```

Should show `active (running)`. If not:

```bash
sudo systemctl start tailscaled
```

### 3. Join the tailnet with subnet routing

```bash
sudo tailscale up \
  --advertise-routes=192.168.50.0/24 \
  --accept-routes
```

This will output a URL. Open it in a browser to authenticate
with your Tailscale account.

### 4. Approve the device in Tailscale admin console

1. Go to https://login.tailscale.com/admin/machines
2. Find ts1 in the device list — it will show as pending approval
3. Click the three-dot menu → Approve
4. Confirm the device is now showing as connected

### 5. Approve the advertised routes

1. In the admin console, click on ts1
2. Under "Subnets" find 192.168.50.0/24
3. Click "Approve" next to the route
4. Confirm the route shows as approved

### 6. Verify subnet routing works

From a Tailscale-connected device outside the LAN (phone, laptop on
a different network), try to reach a LAN device:

```bash
ping 192.168.50.101
```

Or open the Proxmox web UI in a browser:

```
https://192.168.50.101:8006
```

If you can reach LAN IPs from a remote device, subnet routing is
working correctly.

### 7. Verify Tailscale status on ts1

```bash
sudo tailscale status
```

Should show ts1 connected and the route listed as advertised.

---

## If ts1 is rebuilt by Proxmox HA

When Proxmox HA restarts ts1 on a different node after a failover,
Tailscale should reconnect automatically using the existing node
registration. No re-join should be required.

If for any reason Tailscale does not reconnect after a failover:

1. SSH into ts1 at its new location (same IP 192.168.50.131)
2. Run `sudo tailscale status` to check connection state
3. If disconnected run `sudo tailscale up --advertise-routes=192.168.50.0/24 --accept-routes`
4. No admin console approval needed for a reconnect of an already
   approved device

---

## Notes

**Why manual:** Taillock (device approval) is enabled on this tailnet.
Automating the join would require either disabling Taillock or storing
a pre-auth key with enough privilege to bypass it — both undermine the
security model. The join is a one-time human action.

**Why a VM and not a pod:** ts1 must survive Kubernetes cluster failure
because it is the remote access path used to recover the cluster. A pod
running in k8s would go down with the cluster, eliminating the recovery
path at exactly the moment it is needed.

**Route approval:** Tailscale requires explicit admin approval of
advertised routes. This is a Tailscale security feature and cannot be
bypassed without disabling route approval in ACL settings, which is
not recommended.
