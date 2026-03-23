# WSL Setup

Management tooling (Ansible, Terraform, kubectl) runs from WSL2 (Ubuntu) on the developer's Windows machine.

---

## SSH Key

Copy your Ansible private key into `~/.ssh/` and set correct permissions:

```bash
cp /mnt/c/Users/<your-user>/path/to/ansible ~/.ssh/ansible
chmod 600 ~/.ssh/ansible
```

Or generate a new key pair:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible -C "ansible@homelab"
```

The **public key** (`~/.ssh/ansible.pub`) is what you paste into Proxmox nodes (step 1.3 of the deployment guide) and into `terraform.tfvars` as `ssh_public_key`.

---

## Ansible

```bash
sudo apt update && sudo apt install -y ansible
ansible-galaxy install -r /path/to/repo/ansible/requirements.yml
```

### Running Ansible

Run from the repo's `ansible/` directory — `ansible.cfg` sets the inventory path automatically:

```bash
cd /path/to/repo/ansible
ansible-playbook playbooks/site.yml
```

Or specify the config explicitly:

```bash
ANSIBLE_CONFIG=/path/to/repo/ansible/ansible.cfg ansible-playbook playbooks/proxmox_config.yml
```

---

## Terraform

```bash
sudo snap install terraform --classic
```

### Running Terraform

```bash
cd /path/to/repo/terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

---

## kubectl

```bash
sudo snap install kubectl --classic
```

### Getting the kubeconfig

After the cluster is up, copy the kubeconfig from ctrl1 and point it at the kube-vip VIP:

```bash
mkdir -p ~/.kube
scp ansible@192.168.50.111:/etc/rancher/k3s/k3s.yaml ~/.kube/config
sed -i 's/127.0.0.1/192.168.50.110/g' ~/.kube/config
chmod 600 ~/.kube/config
kubectl get nodes
```