# Seceoknight Security Platform

Seceoknight is a comprehensive security monitoring and threat detection platform that provides real-time analysis of security alerts, log aggregation, and threat intelligence integration.

## Overview

Seceoknight combines powerful indexing capabilities with advanced security monitoring to deliver a robust security information and event management (SIEM) solution. The platform collects, analyzes, and correlates security events from across your infrastructure.

## Features

- **Real-time Security Monitoring**: Continuous analysis of security events and alerts
- **Advanced Log Aggregation**: Centralized collection and indexing of security logs
- **Threat Intelligence Integration**: Built-in support for multiple threat intelligence sources
- **Custom Rule Engine**: Flexible rule-based detection system
- **RESTful API**: Full API access for integration with custom dashboards
- **Scalable Architecture**: Designed for small deployments to enterprise environments

## System Requirements

### Minimum Requirements
- **OS**: Ubuntu 20.04/22.04 LTS, Debian 11/12, CentOS 7/8, RHEL 8/9, Amazon Linux 2
- **CPU**: 2 cores
- **RAM**: 4 GB
- **Disk**: 50 GB available space
- **Network**: Internet connection for initial installation

### Recommended Requirements
- **CPU**: 4+ cores
- **RAM**: 8+ GB
- **Disk**: 100+ GB SSD storage

## Installation

### Quick Install

```bash
# Download the installer
curl -sSL "https://raw.githubusercontent.com/SecureSiem/Seceoknight-Collector/main/seceoknight-install.sh" -o seceoknight-install.sh

# Make it executable
chmod +x seceoknight-install.sh

# Run the installer
sudo ./seceoknight-install.sh
```

### What Gets Installed

The installer automatically sets up:

1. **Seceoknight Manager** - Core security monitoring engine
2. **Seceoknight Indexer** - Search and analytics engine for security data
3. **Seceoknight Filebeat** - Log shipper for data collection
4. **Custom Rules** - Security detection rules from your repository
5. **Custom Decoders** - Log parsing decoders from your repository

## Service Management

After installation, Seceoknight runs as three system services that you can manage using standard systemctl commands.

### Check Service Status

```bash
# Check if all services are running
systemctl status seceoknight-manager.service
systemctl status seceoknight-indexer.service
systemctl status seceoknight-filebeat.service
```

### Start Services

```bash
# Start all services
sudo systemctl start seceoknight-indexer.service
sudo systemctl start seceoknight-manager.service
sudo systemctl start seceoknight-filebeat.service

# Or start them one by one in order:
sudo systemctl start seceoknight-indexer.service    # Start first
sleep 10
sudo systemctl start seceoknight-manager.service    # Start second
sleep 5
sudo systemctl start seceoknight-filebeat.service    # Start third
```

### Stop Services

```bash
# Stop all services
sudo systemctl stop seceoknight-filebeat.service
sudo systemctl stop seceoknight-manager.service
sudo systemctl stop seceoknight-indexer.service

# Or stop them in reverse order:
sudo systemctl stop seceoknight-filebeat.service    # Stop first
sudo systemctl stop seceoknight-manager.service    # Stop second
sudo systemctl stop seceoknight-indexer.service    # Stop last
```

### Restart Services

```bash
# Restart a specific service
sudo systemctl restart seceoknight-manager.service

# Restart all services
sudo systemctl restart seceoknight-indexer.service
sudo systemctl restart seceoknight-manager.service
sudo systemctl restart seceoknight-filebeat.service
```

### Enable/Disable Auto-Start

```bash
# Enable services to start automatically on boot
sudo systemctl enable seceoknight-indexer.service
sudo systemctl enable seceoknight-manager.service
sudo systemctl enable seceoknight-filebeat.service

# Disable auto-start
sudo systemctl disable seceoknight-filebeat.service
sudo systemctl disable seceoknight-manager.service
sudo systemctl disable seceoknight-indexer.service
```

### View Service Logs

```bash
# View real-time logs for a service
sudo journalctl -u seceoknight-manager.service -f

# View recent logs
sudo journalctl -u seceoknight-manager.service --since "1 hour ago"

# View all logs since installation
sudo journalctl -u seceoknight-manager.service
```

## Connecting Your Custom Dashboard

After installation, Seceoknight generates connection credentials that you need to copy to your custom dashboard's environment file.

### Where to Find Credentials

The installer creates two files with connection details:

```bash
# Environment file format
cat /var/ossec/api/configuration/dashboard.env

# JSON format
cat /var/ossec/api/configuration/dashboard.json
```

### Copying Credentials to Your Dashboard

1. **After installation completes**, the installer displays all connection details:

   ```
   ════════════════════════════════════════════════════════════
     COPY THESE VALUES TO YOUR DASHBOARD SERVER .env FILE      
   ════════════════════════════════════════════════════════════
   
   # Seceoknight API Configuration
   SECEOKNIGHT_HOST=192.168.1.100
   SECEOKNIGHT_PORT=55000
   SECEOKNIGHT_USERNAME=seceoknight
   SECEOKNIGHT_PASSWORD=auto-generated-password
   
   # JWT Secret
   JWT_SECRET=auto-generated-secret-key
   
   # Indexer Configuration
   INDEXER_HOST=192.168.1.100
   INDEXER_PORT=9200
   INDEXER_USERNAME=admin
   INDEXER_PASSWORD=auto-generated-password
   ```

2. **Copy these values** to your dashboard server's `.env` file:

   ```bash
   # On your dashboard server, create or edit .env file
   nano /path/to/your/dashboard/.env
   
   # Paste the values from the installation output
   SECEOKNIGHT_HOST=192.168.1.100
   SECEOKNIGHT_PORT=55000
   SECEOKNIGHT_USERNAME=seceoknight
   SECEOKNIGHT_PASSWORD=your-generated-password
   JWT_SECRET=your-generated-secret
   INDEXER_HOST=192.168.1.100
   INDEXER_PORT=9200
   INDEXER_USERNAME=admin
   INDEXER_PASSWORD=your-indexer-password
   ```

3. **Restart your dashboard** to apply the new configuration.

### API Endpoints

Your dashboard can connect to these endpoints:

| Service | Endpoint | Protocol |
|---------|----------|----------|
| Seceoknight API | `https://<server-ip>:55000` | HTTPS |
| Seceoknight Indexer | `https://<server-ip>:9200` | HTTPS |

### Testing the Connection

From your dashboard server, test connectivity:

```bash
# Test API connection (replace with your actual IP)
curl -k -u seceoknight:your-password https://192.168.1.100:55000/

# Test Indexer connection
curl -k -u admin:your-password https://192.168.1.100:9200/
```

## Custom Rules and Decoders

Seceoknight automatically downloads custom security rules and decoders from this repository during installation.

### Repository Structure

```
Seceoknight-Collector/
├── seceoknight-install.sh    # Main installer script
├── Local/
│   └── local_rules.xml       # Custom detection rules
└── Decoder/
    └── local_decoder.xml     # Custom log decoders
```

### Updating Rules After Installation

If you update rules in this repository, you can manually download them to your Seceoknight server:

```bash
# Download updated rules
sudo curl -sSL "https://raw.githubusercontent.com/SecureSiem/Seceoknight-Collector/main/Local/local_rules.xml" \
  -o /var/ossec/etc/rules/local_rules.xml

# Download updated decoders
sudo curl -sSL "https://raw.githubusercontent.com/SecureSiem/Seceoknight-Collector/main/Decoder/local_decoder.xml" \
  -o /var/ossec/etc/decoders/local_decoder.xml

# Set correct permissions (REQUIRED - exactly as shown)
sudo chmod 777 /var/ossec/etc/rules/local_rules.xml
sudo chmod 777 /var/ossec/etc/decoders/local_decoder.xml
sudo chown wazuh:wazuh /var/ossec/etc/rules/local_rules.xml
sudo chown wazuh:wazuh /var/ossec/etc/decoders/local_decoder.xml

# Restart manager to apply changes
sudo systemctl restart seceoknight-manager.service
```

**Important Permission Settings:**
| File | Permissions | Ownership | Purpose |
|------|-------------|-----------|---------|
| `local_rules.xml` | `777` (rwxrwxrwx) | `wazuh:wazuh` | Full read/write/execute for all users |
| `local_decoder.xml` | `777` (rwxrwxrwx) | `wazuh:wazuh` | Full read/write/execute for all users |

## Network Configuration

### Firewall Ports

Ensure these ports are open for your dashboard to connect:

| Port | Service | Direction | Purpose |
|------|---------|-----------|---------|
| 9200 | Indexer | Inbound | API and data queries |
| 55000 | Manager API | Inbound | Security alerts and management |
| 1514 | Manager | Inbound | Agent event collection (TCP) |
| 1515 | Manager | Inbound | Agent registration (TCP) |

### Firewall Configuration Examples

**UFW (Ubuntu/Debian):**
```bash
sudo ufw allow 9200/tcp
sudo ufw allow 55000/tcp
sudo ufw allow 1514/tcp
sudo ufw allow 1515/tcp
sudo ufw reload
```

**Firewalld (CentOS/RHEL):**
```bash
sudo firewall-cmd --permanent --add-port=9200/tcp
sudo firewall-cmd --permanent --add-port=55000/tcp
sudo firewall-cmd --permanent --add-port=1514/tcp
sudo firewall-cmd --permanent --add-port=1515/tcp
sudo firewall-cmd --reload
```

## Installation Output

After successful installation, the script displays a **comprehensive summary** with all connection details for your custom dashboard:

### What's Displayed After Installation

```
╔══════════════════════════════════════════════════════════════════════╗
║              SECEOKNIGHT INSTALLATION COMPLETE!                    ║
╚══════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────┐
│  SERVICES STATUS                                                    │
└─────────────────────────────────────────────────────────────────────┘
  ● Seceoknight Indexer:  active
  ● Seceoknight Manager:  active
  ● Seceoknight Filebeat: active

┌─────────────────────────────────────────────────────────────────────┐
│  SERVER INFORMATION                                                 │
└─────────────────────────────────────────────────────────────────────┘
  Server IP:     192.168.1.100
  Server Host:   https://192.168.1.100

┌─────────────────────────────────────────────────────────────────────┐
│  CONNECTION ENDPOINTS FOR YOUR CUSTOM DASHBOARD                     │
└─────────────────────────────────────────────────────────────────────┘
  OpenSearch API:  https://192.168.1.100:9200
  Wazuh API:       https://192.168.1.100:55000

╔══════════════════════════════════════════════════════════════════════╗
║        COPY THESE VALUES TO YOUR CUSTOM DASHBOARD .env FILE          ║
╚══════════════════════════════════════════════════════════════════════╝

# ═══════════════════════════════════════════════════════════════
# WAZUH API CONFIGURATION
# ═══════════════════════════════════════════════════════════════
WAZUH_HOST=192.168.1.100
WAZUH_PORT=55000
WAZUH_USERNAME=wazuh
WAZUH_PASSWORD=auto-generated-password

# ═══════════════════════════════════════════════════════════════
# JWT AUTHENTICATION (for dashboard session management)
# ═══════════════════════════════════════════════════════════════
JWT_SECRET=auto-generated-secret-key

# ═══════════════════════════════════════════════════════════════
# OPENSEARCH CONFIGURATION (for alerts and logs)
# ═══════════════════════════════════════════════════════════════
OPENSEARCH_HOST=192.168.1.100
OPENSEARCH_PORT=9200
OPENSEARCH_USERNAME=admin
OPENSEARCH_PASSWORD=auto-generated-password
```

### Configuration Files Location

After installation, find your connection details in:
- `/var/ossec/api/configuration/dashboard.env` - Environment file format
- `/var/ossec/api/configuration/dashboard.json` - JSON format

### Copy to Your Dashboard Server

```bash
scp /var/ossec/api/configuration/dashboard.env user@dashboard-server:/path/to/dashboard/
```

### Index Information

Your dashboard should query these indices:
- **Alert Indices**: `wazuh-alerts-4.x-*`
- **Archive Indices**: `wazuh-archives-4.x-*`
- **Monitoring**: `.wazuh-*`

## Installation Log

The installation process is logged to:
- **Log File**: `/var/log/seceoknight-install.log`

View the log:
```bash
sudo tail -f /var/log/seceoknight-install.log
```

Or view the entire log:
```bash
sudo cat /var/log/seceoknight-install.log
```

## Troubleshooting

### Services Won't Start

Check for errors in the logs:
```bash
sudo journalctl -u seceoknight-manager.service -n 50
sudo journalctl -u seceoknight-indexer.service -n 50
```

### View Installation Log

If installation fails, check the detailed log:
```bash
sudo cat /var/log/seceoknight-install.log
```

### Dashboard Can't Connect

1. Verify Seceoknight services are running:
   ```bash
   systemctl status seceoknight-manager.service
   systemctl status seceoknight-indexer.service
   ```

2. Check firewall rules allow connections from dashboard IP

3. Verify credentials in `/var/ossec/api/configuration/dashboard.env`

### Permission Issues

If you see permission errors:
```bash
# Fix permissions on custom rules
sudo chmod 777 /var/ossec/etc/rules/local_rules.xml
sudo chown seceoknight:seceoknight /var/ossec/etc/rules/local_rules.xml

# Fix permissions on custom decoders
sudo chmod 777 /var/ossec/etc/decoders/local_decoder.xml
sudo chown seceoknight:seceoknight /var/ossec/etc/decoders/local_decoder.xml

# Restart services
sudo systemctl restart seceoknight-manager.service
```

## Security Considerations

- **Change Default Passwords**: After installation, update any default credentials
- **Firewall Access**: Restrict ports 9200 and 55000 to your dashboard IP only
- **SSL/TLS**: Seceoknight uses self-signed certificates by default. For production, consider using valid SSL certificates
- **Regular Updates**: Keep your custom rules updated in this repository

## Support

For issues, questions, or contributions related to the Seceoknight installer or custom rules:

- **Repository**: https://github.com/SecureSiem/Seceoknight-Collector
- **Issues**: Open an issue on GitHub
- **Custom Dashboard**: Refer to your custom dashboard documentation for dashboard-specific questions

## License

This installer and configuration files are provided as-is for security monitoring purposes.

---

**Note**: Seceoknight is designed to work with custom dashboards. The platform provides the backend security monitoring infrastructure, while your custom dashboard provides the visualization and user interface.
