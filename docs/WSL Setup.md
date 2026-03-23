# SSH Keys
Copy private SSH Ket into ~/.ssh/ansible

# Ansible
## Install Ansible
```bash
sudo apt install ansible -y
ansible-galaxy install -r requirements.yml
```
## Run Ansible
```bash
cd /mnt/c/Users/kdsch/OneDrive/Desktop/Home-Lab/ansible
ANSIBLE_CONFIG=/mnt/c/Users/kdsch/OneDrive/Desktop/Home-Lab/ansible/ansible.cfg   ansible-playbook playbooks/proxmox_config.yml
```

# Terraform
## Installing Terraform
```bash
sudo snap install terraform --classic
```
## Running Terraform
```bash
cd /mnt/c/Users/kdsch/OneDrive/Desktop/Home-Lab/terraform
terraform init
# Save the plan to a file
terraform plan -out=tfplan

# Apply exactly that saved plan (no confirmation prompt needed)
terraform apply tfplan
```