output "ts1_ip" {
  description = "IP address of ts1 (Tailscale subnet router)"
  value       = "192.168.50.131"
}

output "vm_summary" {
  description = "Summary of all deployed VMs"
  value = {
    ts1     = "ts1.kds-dev.com  → 192.168.50.131 (node1, HA enabled, Tailscale subnet router)"
    ctrl01  = "ctrl01.kds-dev.com  → 192.168.50.111 (node1, pinned)"
    ctrl02  = "ctrl02.kds-dev.com  → 192.168.50.112 (node2, pinned)"
    ctrl03  = "ctrl03.kds-dev.com  → 192.168.50.113 (node3, pinned)"
    work01  = "work01.kds-dev.com  → 192.168.50.121 (node1, pinned)"
    work02  = "work02.kds-dev.com  → 192.168.50.122 (node2, pinned)"
    work03  = "work03.kds-dev.com  → 192.168.50.123 (node3, pinned)"
  }
}
