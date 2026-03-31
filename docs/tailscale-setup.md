# Tailscale Setup

Ansible installs and starts `tailscaled` on `ts1` but does not join the tailnet. Joining is manual because Taillock (device approval) is enabled — automating around it would defeat the point.

Run this once after `site.yml` completes. Only needs to be repeated if `ts1` is rebuilt from scratch.

---

## Join the Tailnet

SSH into `ts1` and bring Tailscale up with subnet routing:

```bash
ssh ansible@192.168.50.131

sudo tailscale up \
  --advertise-routes=192.168.50.0/24 \
  --accept-routes
```

This outputs a URL — open it in a browser and authenticate with your Tailscale account.

---

## Approve in the Admin Console

Go to [login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines):

1. Approve `ts1` — it will show as pending
2. Click into `ts1` → under **Subnets** approve `192.168.50.0/24`

---

## Verify

From a Tailscale-connected device off the LAN, confirm the subnet route is working:

```bash
ping 192.168.50.101
```

Or open the Proxmox UI at `https://192.168.50.101:8006`.

---

## After a Proxmox HA Failover

Tailscale should reconnect automatically — no re-join or admin approval needed. If it doesn't:

```bash
ssh ansible@192.168.50.131
sudo tailscale up --advertise-routes=192.168.50.0/24 --accept-routes
```

---

## Why It's Done This Way

**Manual join** — Taillock requires human approval. Automating it means storing a pre-auth key with bypass privileges, which undermines the security model.

**VM, not a pod** — `ts1` is the recovery path if the k3s cluster goes down. Running it as a pod would take it offline at exactly the moment it's needed.
