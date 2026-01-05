#!/usr/bin/env python3

import psutil
import os
import subprocess
import logging
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
import time
from threading import Thread
import requests
import speedtest


class NetworkMonitor:
    """Class to handle network metrics with time series data"""
    
    def __init__(self):
        self.last_network_io = None
        self.last_check_time = None
        self.upload_speeds = []  # Store recent upload speeds
        self.download_speeds = []  # Store recent download speeds
        self.latencies = []  # Store recent latencies
        self.max_history = 10  # Keep last 10 measurements for smoothing
        
    def get_network_io_counters(self):
        """Get current network I/O statistics"""
        try:
            # Get network stats, handle potential permission issues
            return psutil.net_io_counters()
        except (PermissionError, OSError, psutil.AccessDenied) as e:
            logging.getLogger('prometheus_exporter').error(f"Permission error getting network I/O: {e}")
            return None
        except Exception as e:
            logging.getLogger('prometheus_exporter').error(f"Error getting network I/O: {e}")
            return None
    
    def calculate_network_speed(self):
        """Calculate network upload/download speed in Mbps"""
        logger = logging.getLogger('prometheus_exporter')
        
        try:
            current_io = self.get_network_io_counters()
            current_time = time.time()
            
            if current_io is None:
                return 0, 0
                
            if self.last_network_io is not None and self.last_check_time is not None:
                time_diff = current_time - self.last_check_time
                
                if time_diff > 0:
                    # Calculate bytes per second
                    bytes_sent_per_sec = (current_io.bytes_sent - self.last_network_io.bytes_sent) / time_diff
                    bytes_recv_per_sec = (current_io.bytes_recv - self.last_network_io.bytes_recv) / time_diff
                    
                    # Convert to Mbps (megabits per second)
                    upload_speed = (bytes_sent_per_sec * 8) / (1024 * 1024)
                    download_speed = (bytes_recv_per_sec * 8) / (1024 * 1024)
                    
                    # Store for averaging (smooth out spikes)
                    self.upload_speeds.append(upload_speed)
                    self.download_speeds.append(download_speed)
                    
                    # Keep only recent measurements
                    if len(self.upload_speeds) > self.max_history:
                        self.upload_speeds.pop(0)
                    if len(self.download_speeds) > self.max_history:
                        self.download_speeds.pop(0)
                    
                    # Return averaged speeds
                    avg_upload = sum(self.upload_speeds) / len(self.upload_speeds)
                    avg_download = sum(self.download_speeds) / len(self.download_speeds)
                    
                    self.last_network_io = current_io
                    self.last_check_time = current_time
                    
                    return round(avg_upload, 2), round(avg_download, 2)
            
            # First measurement - store but return 0
            self.last_network_io = current_io
            self.last_check_time = current_time
            return 0, 0
            
        except Exception as e:
            logger.error(f"Error calculating network speed: {e}")
            return 0, 0
    
    def measure_latency(self, host='8.8.8.8', count=3):
        """Measure network latency using ping"""
        logger = logging.getLogger('prometheus_exporter')
        
        try:
            result = subprocess.run(
                ['ping', '-c', str(count), '-W', '3', host],
                capture_output=True,
                text=True,
                timeout=15,
                stdin=subprocess.DEVNULL
            )
            
            if result.returncode == 0:
                # Parse ping output for average latency
                lines = result.stdout.split('\n')
                for line in lines:
                    if ('avg' in line or 'rtt' in line) and 'ms' in line:
                        # Handle Rocky Linux ping format
                        if '=' in line:
                            try:
                                parts = line.split('=')[1].strip().split('/')
                                if len(parts) >= 2:
                                    avg_latency = float(parts[1])
                                    
                                    # Store for smoothing
                                    self.latencies.append(avg_latency)
                                    if len(self.latencies) > self.max_history:
                                        self.latencies.pop(0)
                                    
                                    return round(sum(self.latencies) / len(self.latencies), 2)
                            except (ValueError, IndexError):
                                continue
            
            return 0
            
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError, BrokenPipeError, OSError) as e:
            logger.error(f"Error measuring latency to {host}: {e}")
            return 0
    
    def run_speedtest(self):
        """Run internet speed test (use sparingly - maybe once per hour)"""
        logger = logging.getLogger('prometheus_exporter')
        
        try:
            # Set timeout and configure speedtest
            st = speedtest.Speedtest(timeout=60)
            st.get_best_server()
            
            download_speed = st.download() / (1024 * 1024)  # Convert to Mbps
            upload_speed = st.upload() / (1024 * 1024)      # Convert to Mbps
            
            return round(download_speed, 2), round(upload_speed, 2)
            
        except (speedtest.ConfigRetrievalError, speedtest.NoMatchedServers, 
                speedtest.SpeedtestException, ConnectionError, OSError, 
                BrokenPipeError) as e:
            logger.error(f"Speedtest failed: {e}")
            return 0, 0
        except Exception as e:
            logger.error(f"Unexpected error in speedtest: {e}")
            return 0, 0


# Global network monitor instance
network_monitor = NetworkMonitor()


class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        logger = logging.getLogger('prometheus_exporter')
        
        if self.path == '/metrics':
            try:
                metrics_data = collect_all_metrics()
                self._send_response(200, 'text/plain', metrics_data.encode())
            except Exception as e:
                logger.error(f"Error generating metrics: {e}")
                self._send_response(500, 'text/plain', b"Error generating metrics\n")
                
        elif self.path == '/health':
            self._send_response(200, 'text/plain', b"OK\n")
            
        elif self.path == '/':
            html = """
            <html>
            <head><title>Prometheus Exporter</title></head>
            <body>
                <h1>Prometheus Exporter</h1>
                <p>Metrics: <a href="/metrics">/metrics</a></p>
                <p>Health: <a href="/health">/health</a></p>
            </body>
            </html>
            """.encode()
            self._send_response(200, 'text/html', html)
        else:
            self._send_response(404, 'text/plain', b"Not Found\n")
    
    def _send_response(self, status_code, content_type, data):
        """Send HTTP response with proper error handling for broken pipes"""
        logger = logging.getLogger('prometheus_exporter')
        try:
            self.send_response(status_code)
            self.send_header('Content-Type', content_type)
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, OSError) as e:
            # Client disconnected - this is normal, just log at debug level
            logger.debug(f"Client disconnected during response: {e}")
        except Exception as e:
            logger.error(f"Unexpected error sending response: {e}")
    
    def log_message(self, format, *args):
        # Suppress default HTTP server logs
        pass


def setup_logging():
    """Setup logging configuration"""
    # Create logger
    logger = logging.getLogger('prometheus_exporter')
    logger.setLevel(logging.INFO)
    
    # Create formatter
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    
    # Try to log to /var/log/messages via syslog, fallback to file
    try:
        # Use syslog handler for Linux systems
        from logging.handlers import SysLogHandler
        syslog_handler = SysLogHandler(address='/dev/log')
        syslog_handler.setFormatter(formatter)
        logger.addHandler(syslog_handler)
    except (FileNotFoundError, PermissionError):
        # Fallback to file logging
        try:
            file_handler = logging.FileHandler('/var/log/prometheus_exporter.log')
            file_handler.setFormatter(formatter)
            logger.addHandler(file_handler)
        except PermissionError:
            # Last resort: log to current directory
            file_handler = logging.FileHandler('prometheus_exporter.log')
            file_handler.setFormatter(formatter)
            logger.addHandler(file_handler)
    
    # Also log to console for debugging
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    return logger


def export_cpu_usage(interval=1) -> int:
    ''' Returns the system CPU usage as a percentage '''
    logger = logging.getLogger('prometheus_exporter')
    try:
        # Get per-core CPU usage
        cpu_percents = psutil.cpu_percent(interval=int(interval), percpu=True)
        # Return average across all cores
        return int(sum(cpu_percents) / len(cpu_percents))
    except Exception as e:
        logger.error(f"Error exporting CPU usage: {e}")
        return 0


def export_memory_usage() -> int:
    ''' Returns the system memory usage as a percentage '''
    logger = logging.getLogger('prometheus_exporter')
    try:
        return int(psutil.virtual_memory().percent)
    except Exception as e:
        logger.error(f"Error exporting memory usage: {e}")
        return 0


def export_disk_usage(path="/srv") -> int:
    ''' Returns disk usage as a percentage for the specified path '''
    logger = logging.getLogger('prometheus_exporter')
    try:
        disk = psutil.disk_usage(path)
        return int((disk.used / disk.total) * 100)
    except Exception as e:
        logger.error(f"Error exporting disk usage for path {path}: {e}")
        return 0

def get_directory_size_du(path):
    ''' Calculate directory size using du command (like your monitoring command) '''
    logger = logging.getLogger('prometheus_exporter')
    try:
        # Use du command to get size in bytes
        result = subprocess.run(
            ['sudo', 'du', '-sb', path],  # -s for summary, -b for bytes
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode == 0:
            # Parse output: "1234567890\t/path/to/directory"
            size_str = result.stdout.strip().split('\t')[0]
            return int(size_str)
        else:
            logger.error(f"du command failed for {path}: {result.stderr}")
            return 0
            
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, ValueError) as e:
        logger.error(f"Error running du command for {path}: {e}")
        return 0

def export_app_disk_usage(base_path="/srv") -> dict:
    ''' Returns disk usage in GB (numeric) for each directory under the specified path '''
    ''' Returns disk usage in bytes for each directory '''
    logger = logging.getLogger('prometheus_exporter')
    try:
        app_usage = {}
        
        for item in os.listdir(base_path):
            item_path = os.path.join(base_path, item)
            
            if os.path.isdir(item_path):
                try:
                    size_bytes = get_directory_size_du(item_path)
                    app_usage[f"{item}_disk_usage_bytes"] = size_bytes
                except (PermissionError, OSError) as e:
                    logger.error(f"Error accessing directory {item_path}: {e}")
                    app_usage[f"{item}_disk_usage_bytes"] = 0
        
        return app_usage
    except Exception as e:
        logger.error(f"Error exporting app disk usage: {e}")
        return {}


def export_tailscale_status():
    ''' Returns 1 if Tailscale service is running, 0 if stopped/failed '''
    logger = logging.getLogger('prometheus_exporter')
    try:
        result = subprocess.run(
            ['systemctl', 'is-active', 'tailscaled'],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        return 1 if result.stdout.strip() == 'active' else 0
        
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError, FileNotFoundError) as e:
        logger.error(f"Error checking Tailscale status: {e}")
        return 0


def export_container_status(container_names=None) -> dict:
    ''' Returns 1 if container is running, 0 if stopped/doesn't exist '''

    logger = logging.getLogger('prometheus_exporter')
    container_status = {}
    
    for container in container_names:
        try:
            # Check if container exists and get its status
            result = subprocess.run(
                ['docker', 'inspect', '--format={{.State.Running}}', container],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                # Container exists, check if it's running
                is_running = result.stdout.strip().lower() == 'true'
                container_status[f'{container}'] = 1 if is_running else 0
            else:
                # Container doesn't exist
                container_status[f'{container}'] = 0
                
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError, FileNotFoundError) as e:
            logger.error(f"Error checking container {container} status: {e}")
            # Docker command failed or doesn't exist
            container_status[f'{container}'] = 0
    
    return container_status


def export_service_status() -> dict:
    ''' Returns 1 if all containers for a service are running, 0 if any are down '''
    logger = logging.getLogger('prometheus_exporter')
    
    # Define service groups - each service maps to required containers
    service_groups = {
        'immich': ['immich_server', 'immich_postgres', 'immich_machine_learning', 'immich_redis'],
        'homepage': ['homepage-dashboard'],
        'mealie': ['mealie', 'mealie-postgres'],
        'caddy': ['caddy'],
        'filebrowser': ['filebrowser'],
        'vaultwarden': ['vaultwarden'],
        'jellyfin': ['jellyfin'],
        'adguardhome': ['adguardhome']
    }
    
    service_status = {}
    
    # Get all container statuses first
    all_containers = []
    for containers in service_groups.values():
        all_containers.extend(containers)
    
    container_status = export_container_status(container_names=all_containers)
    
    # Check each service group
    for service, required_containers in service_groups.items():
        service_up = 1  # Assume service is up
        
        for container in required_containers:
            container_key = f'{container}'
            if container_key not in container_status or container_status[container_key] == 0:
                service_up = 0  # Service is down if any container is down
                logger.debug(f"Service {service} is down - container {container} not running")
                break
        
        service_status[f'{service}_running'] = service_up
        if service_up:
            logger.debug(f"Service {service} is up - all containers running")
    
    return service_status


def export_internet_status(test_hosts=None) -> int:
    ''' Returns 1 if internet is up (can ping external servers), 0 if down '''
    logger = logging.getLogger('prometheus_exporter')
        
    for host in test_hosts:
        try:
            # Ping with 1 packet, 3 second timeout
            result = subprocess.run(
                ['ping', '-c', '1', '-W', '3', host],
                capture_output=True,
                text=True,
                timeout=5
            )
            
            # If any ping succeeds, internet is up
            if result.returncode == 0:
                return 1
                
        except (subprocess.TimeoutExpired, subprocess.CalledProcessError, FileNotFoundError) as e:
            logger.error(f"Error checking internet status for host {host}: {e}")
            # Continue to next host if this one fails
            continue
    
    # All pings failed
    return 0


def export_network_speed():
    """Export current network speed metrics"""
    upload_speed, download_speed = network_monitor.calculate_network_speed()
    return {
        'network_upload_speed_mbps': upload_speed,
        'network_download_speed_mbps': download_speed
    }


def export_network_latency():
    """Export network latency metrics"""
    latency = network_monitor.measure_latency()
    return {
        'network_latency_ms': latency
    }


def export_speedtest_metrics():
    """Export internet speed test results (run less frequently)"""
    # Only run speedtest every hour to avoid overloading your connection
    current_time = time.time()
    if not hasattr(export_speedtest_metrics, 'last_speedtest'):
        export_speedtest_metrics.last_speedtest = 0
        export_speedtest_metrics.last_download = 0
        export_speedtest_metrics.last_upload = 0
    
    # Run speedtest every 3600 seconds (1 hour)
    if current_time - export_speedtest_metrics.last_speedtest > 3600:
        try:
            download_speed, upload_speed = network_monitor.run_speedtest()
            export_speedtest_metrics.last_download = download_speed
            export_speedtest_metrics.last_upload = upload_speed
            export_speedtest_metrics.last_speedtest = current_time
        except Exception as e:
            logging.getLogger('prometheus_exporter').error(f"Speedtest failed (likely internet down): {e}")
            # Set speeds to 0 when speedtest fails (internet likely down)
            export_speedtest_metrics.last_download = 0
            export_speedtest_metrics.last_upload = 0
            export_speedtest_metrics.last_speedtest = current_time  # Update timestamp to avoid immediate retry
    
    # Return cached values (either successful results or 0 if failed)
    return {
        'internet_download_speed_mbps': export_speedtest_metrics.last_download,
        'internet_upload_speed_mbps': export_speedtest_metrics.last_upload
    }


def collect_all_metrics() -> str:
    """Collect all metrics and format them for Prometheus"""
    logger = logging.getLogger('prometheus_exporter')
    logger.info("Collecting metrics for Prometheus")
    metrics = []

    # CPU Usage
    cpu_usage = export_cpu_usage(interval=2) 
    metrics.append(f"cpu_usage_percent {cpu_usage}")
    
    # Memory Usage
    memory_usage = export_memory_usage()
    metrics.append(f"memory_usage_percent {memory_usage}")
    
    # Disk Usage
    disk_usage = export_disk_usage(path="/srv")
    metrics.append(f"disk_usage_percent {disk_usage}")
    
    # App Disk Usage
    app_disk_usage = export_app_disk_usage(base_path="/srv")
    for app, size_gb in app_disk_usage.items():
        metrics.append(f"{app} {size_gb}")
    
    # Network Speed Metrics (real-time)
    network_speed = export_network_speed()
    for metric, value in network_speed.items():
        metrics.append(f"{metric} {value}")
    
    # Network Latency
    network_latency = export_network_latency()
    for metric, value in network_latency.items():
        metrics.append(f"{metric} {value}")
    
    # Internet Speed Test (hourly)
    speedtest_metrics = export_speedtest_metrics()
    for metric, value in speedtest_metrics.items():
        metrics.append(f"{metric} {value}")
    
    # Tailscale Status
    tailscale_status = export_tailscale_status()
    metrics.append(f"tailscaled_running {tailscale_status}")
    
    # Service Status (grouped containers)
    service_status = export_service_status()
    for service, status in service_status.items():
        metrics.append(f"{service} {status}")
    
    # Internet Status
    internet_status = export_internet_status(test_hosts=['8.8.8.8', '1.1.1.1'])
    metrics.append(f"internet_up {internet_status}")
    
    return '\n'.join(metrics) + '\n'


def run_http_server(port=9090):
    """Run HTTP server to expose metrics for Prometheus scraping"""
    logger = logging.getLogger('prometheus_exporter')
    server = HTTPServer(('0.0.0.0', port), MetricsHandler)
    logger.info(f"Starting HTTP server on port {port}")
    logger.info("Metrics server started on http://0.0.0.0:9090/metrics")
    try:
        server.serve_forever()
    except Exception as e:
        logger.error(f"HTTP server error: {e}")


def main():
    logger = setup_logging()
    logger.info("Prometheus Exporter starting up")
    run_http_server(port=9090)


if __name__ == "__main__":
    main()