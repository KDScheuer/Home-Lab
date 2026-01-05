# Installing VaultWarden

![VaultWarden](/Assets/vaultwarden.png)

### Create Directories for Persistent Data
```bash
sudo mkdir -p /srv/vaultwarden/data
sudo chown -R $USER:$USER /srv/vaultwarden
ls -la /srv/vaultwarden
```

### Create Environment File
```bash
mkdir -p ~/docker/vaultwarden
cp .env.example .env
vi ~/docker/vaultwarden/.env
```

Configured environment variables for domain, admin token, and SMTP settings for email functionality.

### Create Docker Compose File
```bash
vi ~/docker/vaultwarden/docker-compose.yml
```

Used the vaultwarden/server:latest image with port 8222 mapped. Connected to the proxy network for Caddy integration and configured environment variables from the .env file.

### Start VaultWarden Container
```bash
cd ~/docker/vaultwarden
docker compose pull
docker compose up -d
docker compose ps
```

Accessed the web interface through Caddy reverse proxy to create the first user account and verify functionality.
ADMIN_TOKEN=your-generated-token-here

# Database URL (SQLite default, can use PostgreSQL/MySQL)
DATABASE_URL=data/db.sqlite3

# Domain configuration (replace with your domain)
DOMAIN=https://vaultwarden.yourdomain.com

# SMTP configuration for email notifications
SMTP_HOST=smtp.gmail.com
SMTP_FROM=vaultwarden@yourdomain.com
SMTP_FROM_NAME=VaultWarden
SMTP_PORT=587
SMTP_SECURITY=starttls
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password

# Security settings
SIGNUPS_ALLOWED=false
INVITATIONS_ALLOWED=true
EMERGENCY_ACCESS_ALLOWED=true
SENDS_ALLOWED=true
WEB_VAULT_ENABLED=true

# Performance and limits
ROCKET_WORKERS=10
DATABASE_MAX_CONNS=10
EXTENDED_LOGGING=true

# File upload limits
ROCKET_LIMITS={json=10485760,form=10485760,file=1073741824}

# Optional: Organization features
ORG_CREATION_USERS=admin@yourdomain.com
```

### Step 4: Create Docker Compose Configuration
Setting up the VaultWarden service definition.

```bash
vi ~/docker/vaultwarden/docker-compose.yml
```

**Key Configuration Elements:**
- Volume mounts for persistent data storage
- Port mapping for web interface
- Environment file integration
- Restart policies for reliability
- Security context configuration

### Step 5: Deploy VaultWarden Container
Starting the password management service.

```bash
docker compose pull
docker compose up -d
docker compose ps
```

**Expected Output:** VaultWarden container running and accessible on the configured port.

### Step 6: Initial Web Setup
Accessing VaultWarden for first-time configuration:

1. **Access Web Vault:**
   - Navigate to `https://vaultwarden.yourdomain.com` (or your configured domain)
   - The interface should load without errors

2. **Admin Panel Access:**
   - Go to `https://vaultwarden.yourdomain.com/admin`
   - Enter the ADMIN_TOKEN from your .env file
   - Configure initial settings

3. **Create First User Account:**
   - Return to main interface
   - Click "Create Account" (if signups enabled) or use invitation system
   - Set up strong master password
   - Complete account verification via email

### Step 7: Admin Panel Configuration
Configuring VaultWarden through the administrative interface:

1. **General Settings:**
   - Domain URL verification
   - Allow new signups (recommended: disable after initial setup)
   - Password hint display settings
   - Icon service configuration

2. **User Management:**
   - Create user invitations
   - Manage existing users
   - Configure user restrictions
   - Set up organizational policies

3. **Email Configuration:**
   - Test SMTP settings
   - Configure email templates
   - Set up invitation emails
   - Verify password reset functionality

## User Management

### Creating User Accounts

**Via Admin Panel:**
1. Access admin panel with ADMIN_TOKEN
2. Navigate to "Users" section
3. Click "Invite User"
4. Enter email address
5. User receives invitation email with setup link

**Via Invitation System:**
```bash
# Enable invitations in .env file
INVITATIONS_ALLOWED=true
SIGNUPS_ALLOWED=false  # Disable open signups
```

### User Permissions and Roles
- **Standard Users**: Full vault access, organization participation
- **Organization Owners**: Manage organization users and policies  
- **Organization Admins**: User management within organizations
- **Organization Users**: Access to shared organization vaults

### Bulk User Management
```bash
# Export user data (via admin panel)
# Import users from CSV (if needed)
# Bulk invitation system through admin interface
```

## Security Configuration

### Two-Factor Authentication Setup
1. Users log into their account
2. Navigate to Account Settings → Security → Two-step Login
3. Configure preferred 2FA method:
   - Authenticator App (TOTP) - Recommended
   - Email verification
   - YubiKey (if supported)
   - FIDO2 WebAuthn

### Password Policies
Configure through admin panel:
- Minimum password complexity
- Master password requirements  
- Password hint policies
- Account lockout settings

### Encryption and Security
- **Client-side Encryption**: All data encrypted before transmission
- **Zero-knowledge Architecture**: Server cannot decrypt user data
- **Secure Key Derivation**: PBKDF2 with high iteration counts
- **Transport Security**: HTTPS required for all connections

## Advanced Features

### Organization Setup
1. **Create Organization:**
   - User account → New Organization
   - Choose organization type (Free/Personal/Enterprise features)
   - Configure organization settings

2. **Organization Management:**
   - Invite users to organization
   - Create collections for shared passwords
   - Set up groups and permissions
   - Configure organization policies

3. **Shared Vault Management:**
   - Create collections for different teams/purposes
   - Assign user permissions (Read/Write/Admin)
   - Share passwords, notes, and secure files
   - Audit access and usage

### Secure File Attachments
```env
# Enable file attachments in .env
ATTACHMENTS_FOLDER=data/attachments
FILE_SIZE_LIMIT=1048576  # 1MB limit per file
```

**Attachment Management:**
- Upload sensitive documents
- Encrypt files client-side
- Share files within organizations
- Configure size and type limits

### Send Feature (Secure Sharing)
Configure temporary secure sharing:
```env
# Enable Bitwarden Send feature
SENDS_ALLOWED=true
SEND_PURGE_SCHEDULE="0 5 * * * *"  # Cleanup schedule
```

**Send Capabilities:**
- Share passwords/text temporarily
- Set expiration dates
- Require access passwords
- Download/access limits

## Database Management

### SQLite (Default)
```bash
# Backup SQLite database
cp /srv/vaultwarden/data/db.sqlite3 /backup/vaultwarden-$(date +%Y%m%d).db

# Database maintenance
sqlite3 /srv/vaultwarden/data/db.sqlite3 "VACUUM;"
sqlite3 /srv/vaultwarden/data/db.sqlite3 "PRAGMA integrity_check;"
```

### PostgreSQL/MySQL Migration
```env
# Example PostgreSQL configuration
DATABASE_URL=postgresql://vaultwarden:password@postgres:5432/vaultwarden

# Example MySQL configuration  
DATABASE_URL=mysql://vaultwarden:password@mysql:3306/vaultwarden
```

**Migration Process:**
1. Set up target database
2. Update DATABASE_URL in .env
3. Restart VaultWarden (automatic migration)
4. Verify data integrity
5. Backup old SQLite file

## Performance Optimization

### Resource Configuration
```yaml
# Add to docker-compose.yml for resource limits
services:
  vaultwarden:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
        reservations:
          memory: 256M
```

### Database Optimization
```env
# Optimize database connections
DATABASE_MAX_CONNS=20
DATABASE_TIMEOUT=30

# Enable connection pooling
DATABASE_CONN_INIT=""
```

### Web Server Optimization
```env
# Optimize Rocket web server
ROCKET_WORKERS=10
ROCKET_KEEP_ALIVE=5
ROCKET_LIMITS={json=10485760,form=10485760}
```

## Monitoring and Maintenance

### Health Monitoring
```bash
# Check VaultWarden status
curl -f http://localhost:8080/alive || echo "VaultWarden is down"

# Monitor container health
docker compose logs vaultwarden --tail 20

# Check database size
du -sh /srv/vaultwarden/data/

# Monitor resource usage
docker stats vaultwarden
```

### Log Analysis
```bash
# View application logs
docker compose logs vaultwarden --follow

# Check authentication logs
docker compose logs vaultwarden | grep -i "login\|auth"

# Monitor failed attempts
docker compose logs vaultwarden | grep -i "failed\|error"

# Export logs for analysis
docker compose logs vaultwarden --since 24h > vaultwarden-$(date +%Y%m%d).log
```

### Performance Metrics
- Monitor login response times
- Track database query performance  
- Check memory and CPU usage patterns
- Analyze user activity patterns

## Backup and Recovery

### Comprehensive Backup Strategy
```bash
#!/bin/bash
# VaultWarden backup script

BACKUP_DATE=$(date +%Y%m%d)
BACKUP_DIR="/backup/vaultwarden-$BACKUP_DATE"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Stop VaultWarden temporarily for consistent backup
cd ~/docker/vaultwarden
docker compose down

# Backup data directory
tar -czf "$BACKUP_DIR/vaultwarden-data.tar.gz" /srv/vaultwarden/data

# Backup configuration
cp .env "$BACKUP_DIR/"
cp docker-compose.yml "$BACKUP_DIR/"

# Restart VaultWarden
docker compose up -d

# Create encrypted archive
gpg --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 \
    --s2k-digest-algo SHA512 --s2k-count 65536 --symmetric \
    --output "vaultwarden-backup-$BACKUP_DATE.gpg" \
    "$BACKUP_DIR/vaultwarden-data.tar.gz"

# Clean up temporary backup directory
rm -rf "$BACKUP_DIR"

echo "Backup completed: vaultwarden-backup-$BACKUP_DATE.gpg"
```

### Automated Backup Schedule
```bash
# Add to crontab for daily backups at 2 AM
0 2 * * * /usr/local/bin/vaultwarden-backup.sh

# Weekly cleanup of old backups
0 3 * * 0 find /backup -name "vaultwarden-backup-*.gpg" -mtime +30 -delete
```

### Disaster Recovery
```bash
# Restore from backup
cd ~/docker/vaultwarden

# Stop current instance
docker compose down

# Decrypt and extract backup
gpg --decrypt vaultwarden-backup-YYYYMMDD.gpg | tar -xzf -

# Restore data directory
sudo rm -rf /srv/vaultwarden/data
sudo mv backup-data /srv/vaultwarden/data
sudo chown -R $USER:$USER /srv/vaultwarden

# Restore configuration
cp backup-.env .env
cp backup-docker-compose.yml docker-compose.yml

# Start VaultWarden
docker compose up -d

# Verify restoration
curl -f http://localhost:8080/alive
```

## Troubleshooting

**Issue: Users Cannot Login**
- Check DOMAIN setting in .env file
- Verify HTTPS is configured properly
- Test SMTP settings for email verification
- Check browser console for JavaScript errors
- Review VaultWarden logs: `docker compose logs vaultwarden`

**Issue: Admin Panel Not Accessible**
- Verify ADMIN_TOKEN in .env file
- Check if token contains special characters (may need escaping)
- Clear browser cache and cookies
- Test with different browser
- Ensure WEB_VAULT_ENABLED=true

**Issue: Email Notifications Not Working**
- Test SMTP settings manually: `telnet smtp-host 587`
- Verify SMTP credentials and app passwords
- Check firewall rules for SMTP ports
- Review email provider security settings
- Test with different SMTP provider

**Issue: Database Connection Errors**
- Check database file permissions: `ls -la /srv/vaultwarden/data/`
- Verify DATABASE_URL format
- Test database connectivity
- Check available disk space: `df -h`
- Review database logs if using external DB

**Issue: File Attachment Upload Failures**
- Check ATTACHMENTS_FOLDER configuration
- Verify file size limits: ROCKET_LIMITS and FILE_SIZE_LIMIT
- Check available disk space
- Review file permissions on attachment folder
- Test with smaller file sizes

**Issue: Poor Performance**
- Monitor container resources: `docker stats vaultwarden`
- Check database size and optimize
- Review ROCKET_WORKERS configuration
- Analyze slow query logs
- Consider external database for better performance

## Security Hardening

### Network Security
- **Reverse Proxy**: Always use HTTPS via Caddy/nginx
- **Firewall Rules**: Restrict direct access to VaultWarden port
- **VPN Access**: Consider VPN-only access for additional security
- **Rate Limiting**: Implement rate limiting in reverse proxy

### Application Security
```env
# Security hardening settings
SIGNUPS_ALLOWED=false           # Disable open registrations
SHOW_PASSWORD_HINT=false        # Hide password hints
DISABLE_ADMIN_TOKEN=false       # Keep admin access (set to true after configuration)
REQUIRE_DEVICE_EMAIL=true       # Require email verification for new devices
IP_HEADER=X-Real-IP             # Trust reverse proxy IP headers
ICON_CACHE_NEGTTL=0            # Disable icon caching
```

### Regular Security Maintenance
```bash
# Regular security tasks
# 1. Update VaultWarden regularly
cd ~/docker/vaultwarden
docker compose pull && docker compose up -d

# 2. Rotate admin token periodically
openssl rand -base64 48  # Generate new token
# Update .env file and restart

# 3. Review user access and remove inactive accounts
# Use admin panel for user management

# 4. Monitor failed login attempts
docker compose logs vaultwarden | grep -i "failed"

# 5. Backup encryption key verification
gpg --list-secret-keys
```

## Client Applications

### Supported Platforms
- **Web Vault**: Full-featured web interface
- **Desktop Apps**: Windows, macOS, Linux applications
- **Mobile Apps**: iOS and Android applications  
- **Browser Extensions**: Chrome, Firefox, Safari, Edge
- **CLI Tools**: Command-line interface for automation

### Client Configuration
1. **Server URL**: `https://vaultwarden.yourdomain.com`
2. **Account Creation**: Use invitation or open signup
3. **2FA Setup**: Configure immediately after account creation
4. **Sync Verification**: Test across multiple devices

### Browser Extension Setup
1. Install Bitwarden extension
2. Configure custom server URL
3. Login with VaultWarden credentials
4. Enable auto-fill and auto-save
5. Test password capture and fill

## Integration with Other Services

### Reverse Proxy Configuration
**Caddy Example:**
```caddyfile
vaultwarden.yourdomain.com {
    reverse_proxy vaultwarden:80
    
    # WebSocket support for notifications
    @websockets {
        header Connection *Upgrade*
        header Upgrade websocket
    }
    reverse_proxy @websockets vaultwarden:3012
    
    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000;"
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        Referrer-Policy strict-origin-when-cross-origin
    }
}
```

### Monitoring Integration
- Set up health checks in monitoring system
- Create alerts for service availability
- Monitor backup completion
- Track user authentication patterns

### Backup Integration
- Integrate with existing backup systems
- Set up offsite backup replication
- Configure backup verification
- Implement disaster recovery testing

## Best Practices

### Security Best Practices
- Use strong, unique admin tokens
- Enable 2FA for all users
- Regular security audits and updates
- Monitor access logs for anomalies
- Implement proper backup encryption
- Use HTTPS for all connections

### Operational Best Practices
- Regular backup testing and verification
- Monitor resource usage and performance
- Keep VaultWarden updated to latest stable version
- Document configuration changes
- Train users on proper password management
- Implement user onboarding procedures

### Data Management
- Regular database maintenance and optimization
- Monitor storage usage growth
- Archive inactive user data
- Implement data retention policies
- Maintain audit logs for compliance

### User Education
- Provide training on password best practices
- Document common troubleshooting steps
- Share guidelines for secure sharing
- Promote use of 2FA across organization
- Regular security awareness updates

VaultWarden provides enterprise-level password management capabilities in a lightweight, self-hosted package. With proper configuration, monitoring, and maintenance, it offers a secure and reliable foundation for organizational password security.
