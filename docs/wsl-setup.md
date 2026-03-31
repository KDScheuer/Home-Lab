# WSL Setup

Getting a fresh Ubuntu WSL instance up to speed for managing the homelab — Terraform, Ansible, kubectl, and Helm all configured and ready to run.

---

## 1. Install Required Tools

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y ansible dos2unix
sudo snap install terraform --classic
sudo snap install kubectl --classic
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

---

## 2. Clone the Repository

```bash
cd ~
git clone -b v2 https://github.com/KDScheuer/Home-Lab.git
```

---

## 3. Configure SSH Key

Copy the Ansible SSH private key into `~/.ssh/` and set correct permissions:

```bash
mkdir -p ~/.ssh
cp /mnt/c/Users/kdsch/.ssh/ansible ~/.ssh/ansible
chmod 600 ~/.ssh/ansible
```

---

## 4. Configure Environment Variables

The `.env` file lives in the repo root and is sourced on every shell open via `~/.bashrc`.
Fill in any missing values (AWS keys, etc.) before sourcing.

```bash
echo "source <(tr -d '\r' < ~/Home-Lab/.env)" >> ~/.bashrc
source ~/.bashrc
```

> If this is a brand new machine with no `.env` yet, copy the example first:
> ```bash
> cp ~/Home-Lab/.env.example ~/Home-Lab/.env
> # Edit ~/Home-Lab/.env and fill in all values, then re-run the source line above
> ```

---

## 5. Configure kubectl

> **This step requires a running cluster.** Skip and return here after completing the cluster deployment in [infra-and-cluster-deployment.md](infra-and-cluster-deployment.md).

```bash
mkdir -p ~/.kube

# Copy kubeconfig from ctrl1
scp -i ~/.ssh/ansible ansible@192.168.50.111:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Point it at the kube-vip VIP instead of localhost
sed -i 's/127.0.0.1/192.168.50.110/g' ~/.kube/config

# Lock down permissions
chmod 600 ~/.kube/config

# Verify — should list all nodes
kubectl get nodes
```
