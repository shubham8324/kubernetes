#!/bin/bash

set -e

PROFILE="dsoc3"
MEMORY=${1:-""}
CPUS=${2:-""}

echo "============================================"
echo " Minikube + Docker + kubectl Setup Script"
echo " Profile: $PROFILE"
echo "============================================"

############################################
# 0️⃣ System Preparation
############################################
echo "Updating system..."
sudo apt update -y
sudo apt upgrade -y

echo "Installing required packages..."
sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

############################################
# 1️⃣ Install Docker
############################################
echo "Installing Docker..."
sudo apt install -y docker.io

echo "Enabling and starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

echo "Verifying Docker status..."
sudo systemctl status docker --no-pager

echo "Adding user to docker group..."
sudo usermod -aG docker $USER

echo "Applying group changes..."
newgrp docker <<EOF
echo "Docker Version:"
docker --version
echo "Running test container..."
docker run hello-world
EOF

############################################
# 2️⃣ Install kubectl
############################################
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/\$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

chmod +x kubectl
sudo mv kubectl /usr/local/bin/

echo "Verifying kubectl..."
kubectl version --client

############################################
# 3️⃣ Install Minikube
############################################
echo "Installing Minikube..."
curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64

sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

echo "Verifying Minikube..."
minikube version

############################################
# 4️⃣ Start Minikube Cluster
############################################
echo "Starting Minikube..."

if [[ -n "$MEMORY" && -n "$CPUS" ]]; then
    echo "Using custom resources: Memory=${MEMORY}MB, CPUs=${CPUS}"
    minikube start --driver=docker --memory=$MEMORY --cpus=$CPUS --profile $PROFILE
else
    echo "Using default resources"
    minikube start --driver=docker --profile $PROFILE
fi

############################################
# 5️⃣ Validate Cluster
############################################
echo "Validating cluster..."
kubectl get nodes

############################################
# 6️⃣ Verify kubelet (Inside Minikube Node)
############################################
echo "Checking kubelet inside Minikube..."
minikube ssh -p $PROFILE "sudo systemctl status kubelet --no-pager"

############################################
# 7️⃣ Operational Commands
############################################
echo "============================================"
echo " Useful Operational Commands:"
echo "--------------------------------------------"
echo "Stop Minikube:"
echo "  minikube stop -p $PROFILE"
echo ""
echo "Delete Minikube:"
echo "  minikube delete -p $PROFILE"
echo ""
echo "List Profiles:"
echo "  minikube profile list"
echo "============================================"

echo "Setup Completed Successfully."
