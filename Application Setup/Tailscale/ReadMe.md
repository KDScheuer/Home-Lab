# Installing Tailscale

![Tailscale](/Assets/tailscale.png)

### Installing Tailscale on the server
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### Start and authenticate Tailscale
```bash
sudo tailscale up
```

Followed the authentication URL to connect the server to my Tailscale network.

### Verify Tailscale is running
```bash
tailscale status
tailscale ip -4
```

Tailscale provided a private IP address allowing secure remote access to the home lab services without exposing them to the internet.

**Authentication Process:**
1. Command will display a URL for device authorization
2. Open the URL in a browser and sign in to Tailscale
3. Authorize the device in the Tailscale admin console
4. Device will receive an IP address in the 100.x.x.x range

### Step 4: Configure Subnet Routing
Advertising local network routes to make home lab services accessible via Tailscale.

```bash
# Advertise your local network subnet (adjust IP range as needed)
sudo tailscale up --advertise-routes=192.168.50.0/24
```

**Network Configuration Notes:**
- Replace `192.168.50.0/24` with your actual local network CIDR
- This allows Tailscale clients to access local network resources
- Routes must be approved in the Tailscale admin console

### Step 5: Configure Tailscale Admin Console
Completing the setup through the web interface.

1. **Access Admin Console:**
   - Navigate to `https://login.tailscale.com/admin/machines`
   - Locate your server in the device list

2. **Approve Subnet Routes:**
   - Click on your server device
   - Find "Subnet routes" section
   - Click "Approve" for the advertised routes
   - Enable "Use as exit node" if desired

3. **Configure Device Settings:**
   - Set device name for easy identification
   - Configure key expiry settings
   - Enable/disable device sharing

### Step 6: Configure DNS Settings
Setting up Split DNS for seamless access to local services.

1. **Navigate to DNS Configuration:**
   - Go to `https://login.tailscale.com/admin/dns`
   - Select "Add nameserver"

2. **Configure Split DNS:**
   - Domain: `kds-dev.com` (your local domain)
   - Nameserver: `192.168.50.200` (your server's local IP)
   - Restrict to search domain: Enable

3. **Test DNS Resolution:**
```bash
# Test from a Tailscale client
nslookup grafana.kds-dev.com
nslookup jellyfin.kds-dev.com
```

## Network Security Hardening

### Step 7: Configure Firewall Rules
Implementing comprehensive security policies for network access control.

```bash
# Allow SSH access (required for remote management)
sudo firewall-cmd --permanent --zone=trusted --add-port=22/tcp

# Allow DNS services (AdGuard Home)
sudo firewall-cmd --permanent --zone=trusted --add-port=53/tcp
sudo firewall-cmd --permanent --zone=trusted --add-port=53/udp
sudo firewall-cmd --permanent --zone=trusted --add-port=853/tcp

# Allow HTTP/HTTPS services (Caddy reverse proxy)
sudo firewall-cmd --permanent --zone=trusted --add-port=80/tcp
sudo firewall-cmd --permanent --zone=trusted --add-port=443/tcp

# Allow Jellyfin direct access (TV compatibility)
sudo firewall-cmd --permanent --zone=trusted --add-port=8096/tcp
```

### Step 8: Define Trusted Network Ranges
Configuring trusted zones for local and Tailscale networks.

```bash
# Add LAN network to trusted zone
sudo firewall-cmd --permanent --add-source=192.168.50.0/24 --zone=trusted

# Add Tailscale network range to trusted zone
sudo firewall-cmd --permanent --add-source=100.64.0.0/10 --zone=trusted
```

**Network Range Explanation:**
- `192.168.50.0/24` - Local LAN network (adjust to your network)
- `100.64.0.0/10` - Tailscale's CGNAT range for device IPs

### Step 9: Implement Service-Specific Access Controls
Restricting sensitive services to LAN-only access.

```bash
# Block SSH access from Tailscale network (allow LAN only)
sudo firewall-cmd --permanent --zone=trusted --add-rich-rule='rule family="ipv4" source address="100.64.0.0/10" port protocol="tcp" port="22" reject'

# Block Jellyfin access from Tailscale network (allow LAN only)
sudo firewall-cmd --permanent --zone=trusted --add-rich-rule='rule family="ipv4" source address="100.64.0.0/10" port protocol="tcp" port="8096" reject'
```

**Security Rationale:**
- SSH access limited to physical network presence
- Jellyfin direct access for TV devices on LAN only
- Other services accessible via Tailscale through reverse proxy

### Step 10: Apply Default Security Policy
Configuring default deny policy for enhanced security.

```bash
# Set default zone to drop (blocks all other traffic)
sudo firewall-cmd --set-default-zone=drop

# Reload firewall configuration
sudo firewall-cmd --reload

# Verify configuration
sudo firewall-cmd --list-all-zones
```

## Advanced Configuration

### Access Control Lists (ACLs)
Implementing granular network access control through Tailscale ACLs.

**Example ACL Configuration:**
```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["group:admins"],
      "dst": ["*:*"]
    },
    {
      "action": "accept",
      "src": ["group:users"],
      "dst": ["tag:homelab:80,443,53"]
    }
  ],
  "groups": {
    "group:admins": ["admin@company.com"],
    "group:users": ["user@company.com"]
  },
  "tagOwners": {
    "tag:homelab": ["group:admins"]
  }
}
```

### Exit Node Configuration
Configuring the server as an exit node for internet traffic routing.

```bash
# Enable IP forwarding
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Advertise as exit node
sudo tailscale up --advertise-exit-node
```

**Exit Node Usage:**
- Allows other devices to route internet traffic through this server
- Useful for accessing geo-restricted content
- Must be approved in Tailscale admin console

### Key Management
Configuring device authentication and key rotation.

```bash
# Check current device status
tailscale status

# Generate auth key for unattended installation
# (Done through admin console: Settings > Auth keys)

# Use auth key for automated setup
sudo tailscale up --authkey=tskey-auth-xxxxx

# Disable key expiry (if needed)
sudo tailscale up --timeout=0
```

## Monitoring and Maintenance

### Connection Status Monitoring
```bash
# Check Tailscale connection status
tailscale status

# View detailed network information
tailscale netcheck

# Check routing table
ip route | grep tailscale

# Monitor Tailscale logs
sudo journalctl -u tailscaled -f
```

### Performance Monitoring
```bash
# Test connectivity to other Tailscale devices
tailscale ping 100.x.x.x

# Check latency and performance
ping -c 10 100.x.x.x

# Monitor bandwidth usage
iftop -i tailscale0

# Check connection quality
tailscale status --peers
```

### Network Troubleshooting
```bash
# Debug connectivity issues
tailscale netcheck --verbose

# Check NAT traversal status
tailscale debug derp-map

# View active connections
ss -tuln | grep tailscale

# Check firewall impact
sudo firewall-cmd --list-all
```

## Troubleshooting Common Issues

**Issue: Device Not Connecting**
- Verify internet connectivity: `ping 8.8.8.8`
- Check service status: `sudo systemctl status tailscaled`
- Review logs: `sudo journalctl -u tailscaled --since "1 hour ago"`
- Restart service: `sudo systemctl restart tailscaled`

**Issue: Subnet Routes Not Working**
- Verify routes are advertised: `tailscale status`
- Check admin console for route approval
- Test local network connectivity
- Verify IP forwarding: `cat /proc/sys/net/ipv4/ip_forward`

**Issue: DNS Resolution Fails**
- Check DNS configuration in admin console
- Verify local DNS server is accessible: `nslookup google.com 192.168.50.200`
- Test from multiple devices
- Review firewall rules for DNS ports

**Issue: Slow Performance**
- Check connection type: `tailscale status` (look for "relay" vs "direct")
- Test with netcheck: `tailscale netcheck`
- Consider firewall/NAT configuration
- Review DERP relay usage

**Issue: Firewall Blocks Connections**
- Temporarily disable firewall: `sudo systemctl stop firewalld`
- Test connectivity
- Review and adjust firewall rules
- Re-enable firewall: `sudo systemctl start firewalld`

## Security Best Practices

### Device Management
- Regularly review connected devices in admin console
- Remove unauthorized or unused devices
- Use device naming conventions for easy identification
- Enable device sharing only when necessary

### Access Control
- Implement least privilege access principles
- Use ACLs for granular network control
- Regular audit of user permissions
- Monitor access logs for suspicious activity

### Network Segmentation
- Separate critical services from general access
- Use firewall rules for defense in depth
- Consider VLANs for additional segmentation
- Limit subnet routing to necessary networks

### Key Management
- Regular key rotation when possible
- Use auth keys for automated deployments
- Monitor key expiration dates
- Secure storage of authentication credentials

## Integration with Home Lab Services

### Reverse Proxy Integration
Configuring Caddy to work with Tailscale networking:

```caddyfile
# Example Caddyfile entries for Tailscale access
grafana.kds-dev.com {
    reverse_proxy grafana:3000
    tls internal
}

jellyfin.kds-dev.com {
    reverse_proxy jellyfin:8096
    tls internal
}
```

### DNS Integration
- Configure local DNS server (AdGuard Home) with Tailscale
- Set up conditional forwarding for external domains
- Implement DNS-based ad blocking for Tailscale clients
- Configure secure DNS over TLS/HTTPS

### Monitoring Integration
- Add Tailscale metrics to Prometheus monitoring
- Create Grafana dashboards for network performance
- Set up alerts for connectivity issues
- Monitor bandwidth usage patterns

## Backup and Recovery

### Configuration Backup
```bash
# Backup Tailscale configuration
sudo cp /var/lib/tailscale/tailscaled.state /backup/tailscale-state-$(date +%Y%m%d)

# Backup device information
tailscale status --json > tailscale-status-$(date +%Y%m%d).json

# Export network configuration
ip route show | grep tailscale > tailscale-routes-$(date +%Y%m%d).txt
```

### Disaster Recovery
```bash
# Reinstall Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Restore configuration
sudo systemctl stop tailscaled
sudo cp /backup/tailscale-state-backup /var/lib/tailscale/tailscaled.state
sudo systemctl start tailscaled

# Re-authenticate if needed
sudo tailscale up --accept-dns=true --advertise-routes=192.168.50.0/24
```

### Documentation
Maintain documentation for:
- Network topology and IP assignments
- Firewall rules and their purposes
- Device inventory and ownership
- Access control policies and procedures
- Emergency contact and recovery procedures

## Performance Optimization

### Connection Optimization
```bash
# Optimize for low latency
sudo tailscale up --netfilter-mode=off

# Prefer IPv6 when available
sudo tailscale up --accept-routes --accept-dns

# Configure custom DERP servers (if needed)
# This requires advanced configuration in ACL policy
```

### Resource Management
- Monitor CPU usage of tailscaled daemon
- Check memory consumption patterns
- Optimize firewall rules for performance
- Consider hardware acceleration for encryption

### Network Tuning
```bash
# Optimize network buffer sizes
echo 'net.core.rmem_max = 16777216' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 16777216' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Monitor network statistics
cat /proc/net/dev | grep tailscale
```

## Future Enhancements

### Planned Improvements
- Integration with identity providers (SSO)
- Enhanced monitoring and alerting
- Automated device provisioning
- Advanced traffic shaping policies
- Multi-site networking expansion

### Scaling Considerations
- Device limits and licensing
- Performance impact of additional routes
- Administrative overhead
- Backup connectivity options
- Compliance and audit requirements

## Conclusion

Tailscale provides a robust, secure networking solution for the home lab environment. The combination of WireGuard encryption, easy management, and flexible access controls makes it an ideal choice for secure remote access and service connectivity. Regular monitoring, maintenance, and security reviews ensure optimal performance and security posture.

**Key Benefits Achieved:**
- Secure remote access to home lab services
- Simplified VPN management without complex configuration
- Granular access control through firewall rules and ACLs
- Seamless integration with existing network infrastructure
- Scalable architecture for future expansion


### Hardening Caddy
Configuring caddy to not serve internal LAN only services via tailscale 
```
example.kds-dev.com {
    import home_tls

    # Allowed IPs (LAN)
    @allowed remote_ip 192.168.50.0/24

    handle @allowed {
        reverse_proxy <example>:<port>
    }

    # Everything else blocked
    handle {
        respond "Forbidden" 403
    }
}
```

### Harening Tailscale
Enabling Tailnet Lock to Prevent Devices being added to tailnet due to account Compormises

Go to `https://tailscale.com/` -> Settings -> Security
Enable Tailnet lock, which will prevent new devices from being added in the event the idp is compromised
Enable Notifications for attempts to add a new device

```bash
sudo tailscale lock init --gen-disablements 10 --confirm 
```

