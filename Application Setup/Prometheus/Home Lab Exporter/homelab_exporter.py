#!/usr/bin/env python3

import subprocess
import logging
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


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


def collect_all_metrics() -> str:
    """Collect all metrics and format them for Prometheus"""
    logger = logging.getLogger('prometheus_exporter')
    logger.info("Collecting metrics for Prometheus")
    metrics = []
    
    # Service Status (grouped containers)
    service_status = export_service_status()
    for service, status in service_status.items():
        metrics.append(f"{service} {status}")
    
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