#!/bin/bash

set -e

PROFILE="dsoc3"
MEMORY=${1:-""}
CPUS=${2:-""}
DRIVER=${3:-"docker"}   # docker | none

echo "============================================"
echo " Minikube Setup Script"
echo " Profile: $PROFILE"
echo " Driver:  $DRIVER"
echo "============================================"

############################################
# Validate Driver
############################################
if [[ "$DRIVER" != "docker" && "$DRIVER" != "none" ]]; then
  echo "Invalid driver. Use 'docker' or 'none'."
  exit 1
fi

############################################
# 0️⃣ System Preparation
############################################
echo "Updating system..."
sudo apt update -y
sudo apt upgrade -y

echo "Installing required base packages..."
sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release conntrack

############################################
# Disable Swap (Required for Kubernetes)
############################################
echo "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

############################################
# 1️⃣ Install kubectl
############################################
if ! command -v kubectl &> /dev/null; then
  echo "Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
fi

kubectl version --client

############################################
# 2️⃣ Install Docker (Only if Docker driver)
############################################
if [[ "$DRIVER" == "docker" ]]; then
  if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo apt install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    echo "⚠ Please logout/login again if docker permission issues occur."
  fi
fi

############################################
# 3️⃣ Install Minikube
############################################
if ! command -v minikube &> /dev/null; then
  echo "Installing Minikube..."
  curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
  rm minikube-linux-amd64
fi

minikube version

############################################
# 4️⃣ Start Minikube
############################################
echo "Starting Minikube..."

if [[ "$DRIVER" == "none" ]]; then
  echo "Starting with NONE driver (VM/Bare Metal mode)"
  sudo minikube start --driver=none --profile $PROFILE
else
  echo "Starting with DOCKER driver"
  if [[ -n "$MEMORY" && -n "$CPUS" ]]; then
      minikube start --driver=docker --memory=$MEMORY --cpus=$CPUS --profile $PROFILE
  else
      minikube start --driver=docker --profile $PROFILE
  fi
fi

############################################
# Fix kubeconfig Permissions (for none driver)
############################################
if [[ "$DRIVER" == "none" ]]; then
  echo "Fixing kubeconfig permissions..."
  sudo chown -R $USER:$USER ~/.kube ~/.minikube || true
fi

############################################
# 5️⃣ Validate Cluster
############################################
echo "Validating cluster..."
kubectl get nodes
minikube status -p $PROFILE

############################################
# 6️⃣ Operational Commands
############################################
echo "============================================"
echo " Useful Operational Commands"
echo "============================================"

echo "List Profiles:"
echo "  minikube profile list"

echo ""
echo "Get Minikube IP:"
echo "  minikube ip"
echo "  minikube ip -p $PROFILE"

echo ""
echo "Stop Cluster:"
echo "  minikube stop -p $PROFILE"

echo ""
echo "Delete Cluster:"
echo "  minikube delete -p $PROFILE"

echo ""
echo "Dashboard:"
echo "  minikube dashboard -p $PROFILE"

echo ""
echo "Access Service:"
echo "  minikube service <service-name> -p $PROFILE"

echo ""
echo "NodePort Range:"
echo "  Default range: 30000-32767"

echo "============================================"
echo " Azure VM – Network & Access Setup"
echo "============================================"

echo ""
echo "1️⃣ Azure NSG Inbound Rule (MANDATORY)"
echo "--------------------------------------------"
echo "Azure Portal → VM → Networking → Add inbound rule:"
echo "  Protocol: TCP"
echo "  Port: 9090 or 30090"
echo "  Action: Allow"

echo ""
echo "2️⃣ If Using Port-Forward"
echo "--------------------------------------------"
echo "  kubectl port-forward -n monitoring svc/prometheus-service 9090:9090 --address 0.0.0.0"
echo ""
echo "  OR"
echo ""
echo "  kubectl port-forward -n monitoring svc/prometheus-service 30090:9090 --address 0.0.0.0"

echo ""
echo "3️⃣ Verify Port Listening"
echo "--------------------------------------------"
echo "  sudo ss -tulnp | grep 9090"
echo "  sudo ss -tulnp | grep 30090"

echo ""
echo "4️⃣ Firewall Check (UFW)"
echo "--------------------------------------------"
echo "  sudo ufw status"
echo ""
echo "If active:"
echo "  sudo ufw allow 9090/tcp"
echo "  sudo ufw allow 30090/tcp"

echo ""
echo "5️⃣ Get Public IP"
echo "--------------------------------------------"
echo "  curl ifconfig.me"

echo ""
echo "6️⃣ Access Prometheus"
echo "--------------------------------------------"
echo "  http://<VM_PUBLIC_IP>:9090"
echo "  OR"
echo "  http://<VM_PUBLIC_IP>:30090"

echo "============================================"
echo "Setup Completed Successfully."
