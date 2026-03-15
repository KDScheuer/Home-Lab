from http.server import HTTPServer, BaseHTTPRequestHandler
import subprocess
import threading

TEMPLATE = open("homenode.ks").read()

def run_ansible(ip):
    result = subprocess.run([
        "ansible-playbook",
        "site.yml",
        "-i", f"{ip},",
    ])
    if result.returncode == 0:
        print(f"[+] Ansible completed successfully for {ip}")
    else:
        print(f"[-] Ansible failed for {ip} with return code {result.returncode}")

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
    
        elif len(parts) == 2 and parts[0] == "ansible":
            ip = parts[1]

            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(f"Ansible request received for {ip}".encode())
            self.log_message(f"Received ansible request for {ip}")
            threading.Thread(
                target=run_ansible,
                args=(ip,)
            ).start() 

        else:    
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"usage: /ks/<ip>/<hostname>")
            return
        
HTTPServer(("0.0.0.0", 8080), KickstartHandler).serve_forever()