from http.server import HTTPServer, BaseHTTPRequestHandler
import subprocess
import threading
import os
import yaml

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ANSIBLE_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "ansible"))
PLAYBOOK = os.path.join(ANSIBLE_DIR, "site.yml")
INVENTORY = os.path.join(ANSIBLE_DIR, "inventory", "hosts.yml")

TEMPLATE = open(os.path.join(BASE_DIR, "homenode.ks")).read()

inventory_lock = threading.Lock()

def register_host(hostname, ip) -> None:
    with inventory_lock:
        with open(INVENTORY) as f:
            inv = yaml.safe_load(f)
        hosts = inv["all"]["children"]["k3s_nodes"]["hosts"]
        if hostname not in hosts:
            hosts[hostname] = {"ansible_host": ip}
            with open(INVENTORY, "w") as f:
                yaml.dump(inv, f, default_flow_style=False)
            print(f"[+] Registered {hostname} ({ip}) in inventory")
        else:
            print(f"[+] {hostname} already in inventory")

def run_ansible(hostname) -> None:
    try:
        result = subprocess.run(
            ["ansible-playbook", "-i", INVENTORY, PLAYBOOK, "--limit", hostname],
            cwd=ANSIBLE_DIR, timeout=300
        )
        if result.returncode == 0:
            print(f"[+] Ansible completed successfully for {hostname}")
        else:
            print(f"[-] Ansible failed for {hostname} with return code {result.returncode}")
    except subprocess.TimeoutExpired:
        print(f"[-] Ansible timed out for {hostname} after 300s")

def validate_ip(ip) -> bool:
    parts = ip.split(".")
    if len(parts) != 4:
        return False
    for part in parts:
        if not part.isdigit():
            return False
        num = int(part)
        if num < 0 or num > 255:
            return False
    return True

def validate_hostname(hostname) -> bool:
    if len(hostname) == 0 or len(hostname) > 255:
        return False
    if hostname[-1] == ".":
        hostname = hostname[:-1]
    if " " in hostname:
        return False
    allowed = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
    for part in hostname.split("."):
        if len(part) == 0 or len(part) > 63:
            return False
        if not all(c in allowed for c in part):
            return False
        if part[0] == "-" or part[-1] == "-":
            return False
    return True

class KickstartHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parts = self.path.strip("/").split("/")
        ip, hostname = None, None

        if len(parts) == 3:
            ip = parts[1] if validate_ip(parts[1]) else None
            hostname = parts[2] if validate_hostname(parts[2]) else None
            if not ip or not hostname:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b"Invalid IP address or hostname")
                return
        
        if parts[0] == "ks" and hostname and ip:
            ks = TEMPLATE.replace("{{ ip }}", ip).replace("{{ hostname }}", hostname)

            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(ks.encode())
            self.log_message("served kickstart for %s (%s)", hostname, ip)
    
        elif parts[0] == "ansible" and hostname and ip:
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(f"Ansible request received for {hostname} ({ip})".encode())
            self.log_message(f"Received ansible request for {hostname} ({ip})")
            register_host(hostname, ip)
            threading.Thread(
                target=run_ansible,
                args=(hostname,)
            ).start() 

        else:    
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"usage: /ks/<ip>/<hostname>")
            return

print("HTTP provisioning server starting on port 8080...")
HTTPServer(("0.0.0.0", 8080), KickstartHandler).serve_forever()
