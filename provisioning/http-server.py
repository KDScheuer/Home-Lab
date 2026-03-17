from http.server import HTTPServer, BaseHTTPRequestHandler
import subprocess
import threading
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
ANSIBLE_DIR = os.path.abspath(os.path.join(BASE_DIR, "..", "ansible"))
PLAYBOOK = os.path.join(ANSIBLE_DIR, "site.yml")

TEMPLATE = open(os.path.join(BASE_DIR, "homenode.ks")).read()

def run_ansible(hostname):
    result = subprocess.run(
        ["ansible-playbook", PLAYBOOK, "--limit", hostname],
        cwd=ANSIBLE_DIR
    )
    if result.returncode == 0:
        print(f"[+] Ansible completed successfully for {hostname}")
    else:
        print(f"[-] Ansible failed for {hostname} with return code {result.returncode}")

class KickstartHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        parts = self.path.strip("/").split("/")
        
        if len(parts) == 3 and parts[0] == "ks":
            ip = parts[1]
            hostname = parts[2]

            ks = TEMPLATE.replace("{{ ip }}", ip).replace("{{ hostname }}", hostname)

            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(ks.encode())
            self.log_message("served kickstart for %s (%s)", hostname, ip)
    
        elif len(parts) == 3 and parts[0] == "ansible":
            ip = parts[1]
            hostname = parts[2]

            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(f"Ansible request received for {hostname} ({ip})".encode())
            self.log_message(f"Received ansible request for {hostname} ({ip})")
            threading.Thread(
                target=run_ansible,
                args=(hostname,)
            ).start() 

        else:    
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"usage: /ks/<ip>/<hostname>")
            return
        
HTTPServer(("0.0.0.0", 8080), KickstartHandler).serve_forever()