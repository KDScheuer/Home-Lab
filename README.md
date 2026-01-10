
# Home Lab Infrastructure
*Production-grade containerized services with monitoring, security, and disaster recovery*

[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?style=flat-square&logo=docker)](https://docker.com)
[![Monitoring](https://img.shields.io/badge/Monitoring-Prometheus%2BGrafana-E6522C?style=flat-square&logo=prometheus)](https://prometheus.io)
[![VPN](https://img.shields.io/badge/VPN-Tailscale-000000?style=flat-square&logo=tailscale)](https://tailscale.com)
[![Reverse Proxy](https://img.shields.io/badge/Proxy-Caddy-1F88C0?style=flat-square&logo=caddy)](https://caddyserver.com)

## 📋 Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Technology Stack](#technology-stack)
- [Key Features](#key-features)
- [Infrastructure Components](#infrastructure-components)
- [Monitoring & Observability](#monitoring--observability)
- [Security & Networking](#security--networking)
- [Disaster Recovery](#disaster-recovery)
- [Repository Structure](#repository-structure)

## 🏠 Overview

A production-ready home lab infrastructure built to demonstrate enterprise-level practices, container orchestration, and system administration skills. This project showcases the design and implementation of a secure, monitored, and highly available service ecosystem using industry-standard tools and methodologies.

**The Why / Problems Solved:** 
I wanted a way to better control what is being displayed to my kids, dns level blocking, and custom content streaming services allowed me to accomplish this. I also wanted a way to remove vendor lockin for cloud based services for photos, videos, documents, passwords, and secrets.

## 🏗️ Architecture
![Network Architecture](/Assets/Network%20Diagram.png)

### Core Design Principles
- **Zero-Trust Networking:** All services behind reverse proxy with TLS termination
- **Infrastructure as Code:** Fully documented, reproducible deployments
- **Observability First:** Custom metrics collection and centralized monitoring
- **Defense in Depth:** Multiple security layers (VPN, DNS filtering, container isolation)

## 🛠️ Technology Stack

| Category | Technology | Purpose |
|----------|------------|---------|
| **Containerization** | Docker Compose | Service orchestration and dependency management |
| **Reverse Proxy** | Caddy | TLS termination, automatic HTTPS, request routing |
| **Monitoring** | Prometheus + Grafana | Metrics collection, alerting, and visualization |
| **VPN** | Tailscale | Secure remote access with mesh networking |
| **DNS/Security** | AdGuard Home | Network-wide ad blocking and DNS management |
| **Certificate Management** | Let's Encrypt + Route 53 | Automated SSL certificate provisioning |
| **Custom Telemetry** | Python Exporter | Host and service health monitoring |

## ✨ Key Features

### **Custom Infrastructure Monitoring**
- **Developed custom Python-based Prometheus exporter** collecting:
  - System resource utilization (CPU, memory, disk)
  - Per-service disk usage tracking
  - Network throughput and latency metrics
  - Service health status and uptime monitoring
  - Internet connectivity and Tailscale daemon status

### **Enterprise Security Model**
- **TLS-everywhere architecture** with automated certificate management
- **Network segmentation** using Docker bridge networks
- **VPN-based access controls** with service-level restrictions
- **DNS-level threat protection** and content filtering

### **Observability & Operations**
- **Real-time infrastructure monitoring** with custom dashboards
- **Automated backup scheduling** with 3-2-1 backup strategy
- **Configuration management** with version-controlled deployments
- **Service health monitoring** with automatic restart policies

![Monitoring Dashboard](/Assets/Grafana%20Dashboard.png)

## 🏢 Infrastructure Components

### Core Services
| Service | Technology | Business Value |
|---------|------------|----------------|
| **Media Streaming** | Jellyfin | Centralized media distribution with client compatibility |
| **Photo Management** | Immich | AI-powered photo organization and backup solution |
| **Password Management** | Vaultwarden | Enterprise-grade credential management |
| **File Storage** | FileBrowser | Secure document repository with web interface |
| **Recipe Management** | Mealie | Digital recipe organization and meal planning |
| **Service Discovery** | Custom Homepage | Centralized application portal |

### Infrastructure Services
- **DNS & Ad Blocking:** AdGuard Home with custom block lists
- **Reverse Proxy:** Caddy with automatic HTTPS and health checks  
- **Monitoring Stack:** Prometheus + Grafana with custom exporters
- **VPN Gateway:** Tailscale for secure remote access

## 📊 Monitoring & Observability

### Custom Metrics Collection
```python
# Example from custom exporter - Enterprise monitoring practices
def collect_service_metrics():
    """Collect containerized service health and resource usage"""
    for service in docker_services:
        metrics.append(f"service_status{{name='{service}'}} {get_status(service)}")
        metrics.append(f"service_disk_usage{{name='{service}'}} {get_disk_usage(service)}")
```
**Example Metrics HTTP Endpoint**
```yml
cpu_usage_percent 1
memory_usage_percent 42
disk_usage_percent 26
immich_disk_usage_bytes 26397647360
mealie_disk_usage_bytes 74141083
jellyfin_disk_usage_bytes 208909549303
caddy_disk_usage_bytes 3433
homepage_disk_usage_bytes 12487
adguardhome_disk_usage_bytes 146294885
certs_disk_usage_bytes 7322
vaultwarden_disk_usage_bytes 420576
filebrowser_disk_usage_bytes 65774
prometheus_disk_usage_bytes 1142105
grafana_disk_usage_bytes 42880554
backups_disk_usage_bytes 26125283278
network_upload_speed_mbps 0.04
network_download_speed_mbps 0.04
network_latency_ms 35.37
internet_download_speed_mbps 384.69
internet_upload_speed_mbps 40.64
tailscaled_running 1
immich_running 1
homepage_running 1
mealie_running 1
caddy_running 1
filebrowser_running 1
vaultwarden_running 1
jellyfin_running 1
adguardhome_running 1
internet_up 1
```

### Key Performance Indicators
- **System Resource Utilization:** Real-time CPU, memory, and storage metrics
- **Service Availability:** 99.9%+ uptime tracking across all services
- **Network Performance:** Internet connectivity and VPN tunnel monitoring
- **Backup Success Rates:** Automated backup verification and alerting

## 🔐 Security & Networking

### Network Architecture
```yaml
# Docker network configuration example
networks:
  proxy:
    name: proxy
    driver: bridge
    internal: false
  internal:
    name: internal  
    driver: bridge
    internal: true
```

### Security Implementations
- **Certificate Management:** Automated Let's Encrypt certificates via DNS-01 challenge
- **Access Control:** Tailscale-based zero-trust network access
- **SSH Hardening:** Key-based authentication only, password login disabled
- **Container Isolation:** Services communicate via internal Docker networks only
- **DNS Security:** Network-wide malware and ad blocking via AdGuard Home

## 💾 Disaster Recovery

### 3-2-1-1-0 Backup Strategy
- **3 Copies:** Production, local backup, offsite backup
- **2 Media Types:** Internal SSD, AWS S3
- **1 Offsite Location:** AWS S3 (Quarterly)
- **1 Air-Gapped Backup** SSD Stored in Fireproof/Waterproof/800+ pound bolted down safe (physical security)
- **0 Errors** Periodic restore testing for each service in place

Local Backups occur Nightly or Weekly depending on the workload being targeted. Files are periodically moved onto an external SSD for the offline ransomware proof copy, as well as into AWS S3 for an offsite immutable copy. 

### Automated Backup Process
```bash
# Crash-consistent backup implementation
1. Pre-backup validation (space, permissions, connectivity)
2. Service graceful shutdown via Docker Compose
3. Data compression using parallel gzip (pigz) 
4. Service restart and health verification
5. Retention policy enforcement
6. Comprehensive logging to syslog
```
---

## 🎯 Skills Demonstrated

**Infrastructure & Operations**
- Container orchestration
- Automated certificate management and PKI
- Network security architecture and implementation
- Monitoring system design and custom instrumentation

**DevOps & Automation**  
- Infrastructure as Code practices
- CI/CD pipeline concepts (backup automation)
- Configuration management and version control
- Disaster recovery planning and implementation

**System Administration**
- Linux system administration and service management
- Network configuration and troubleshooting
- Security hardening and access control
- Performance monitoring and capacity planning
