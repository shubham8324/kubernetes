
#!/bin/bash

set -euo pipefail

PROFILE="dsoc3"
MEMORY=${1:-""}
CPUS=${2:-""}
DRIVER=${3:-"docker"}   # docker | none

echo "============================================"
echo " Minikube Hardened Setup Script"
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
# Resource Guard (Minimum 2GB RAM)
############################################
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_MEM" -lt 2048 ]; then
  echo "Minimum 2GB RAM required. Current: ${TOTAL_MEM}MB"
  exit 1
fi

############################################
# System Preparation
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
# Load Required Kernel Modules
############################################
echo "Configuring kernel modules..."
sudo modprobe overlay
sudo modprobe br_netfilter

echo -e "overlay\nbr_netfilter" | sudo tee /etc/modules-load.d/k8s.conf

############################################
# Configure Sysctl for Kubernetes Networking
############################################
echo "Applying sysctl settings..."
sudo tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

############################################
# Install kubectl
############################################
if ! command -v kubectl &> /dev/null; then
  echo "Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
fi

kubectl version --client

############################################
# Install Docker (If Docker Driver)
############################################
if [[ "$DRIVER" == "docker" ]]; then
  if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo apt install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    echo "⚠ Logout/login required if docker permission error occurs."
  fi
fi

############################################
# Install Minikube
############################################
if ! command -v minikube &> /dev/null; then
  echo "Installing Minikube..."
  curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
  sudo install minikube-linux-amd64 /usr/local/bin/minikube
  rm minikube-linux-amd64
fi

minikube version

############################################
# Start Minikube
############################################
echo "Starting Minikube..."

if [[ "$DRIVER" == "none" ]]; then
  sudo minikube start --driver=none --profile $PROFILE --wait=all
else
  if [[ -n "$MEMORY" && -n "$CPUS" ]]; then
    minikube start \
      --driver=docker \
      --memory=$MEMORY \
      --cpus=$CPUS \
      --disk-size=20g \
      --profile $PROFILE \
      --wait=all
  else
    minikube start \
      --driver=docker \
      --disk-size=20g \
      --profile $PROFILE \
      --wait=all
  fi
fi

############################################
# Fix kubeconfig Permissions (none driver)
############################################
if [[ "$DRIVER" == "none" ]]; then
  sudo chown -R $USER:$USER ~/.kube ~/.minikube || true
fi

############################################
# Ensure kubectl Context
############################################
kubectl config use-context $PROFILE

############################################
# Enable Useful Addons
############################################
echo "Enabling addons..."
minikube addons enable metrics-server -p $PROFILE
minikube addons enable ingress -p $PROFILE

############################################
# Validate Cluster
############################################
echo "Validating cluster..."
kubectl get nodes
minikube status -p $PROFILE

echo "============================================"
echo "Cluster Ready."
echo "============================================"

echo ""
echo "Useful Commands:"
echo "  minikube profile list"
echo "  minikube ip -p $PROFILE"
echo "  minikube dashboard -p $PROFILE"
echo "  minikube stop -p $PROFILE"
echo "  minikube delete -p $PROFILE"

echo ""
echo "NodePort Range: 30000-32767"
echo ""
echo "Get VM Public IP:"
echo "  curl ifconfig.me"

echo ""
echo "Setup Completed Successfully."

