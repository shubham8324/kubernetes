#!/bin/bash

set -e

PROFILE="dsoc3"

echo "========== SYSTEM PREPARATION =========="
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

echo "========== INSTALLING DOCKER =========="
if ! command -v docker &> /dev/null; then
    sudo apt install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
fi

sudo usermod -aG docker $USER || true

echo "Docker Version:"
docker --version || true

echo "========== INSTALLING kubectl =========="
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

kubectl version --client

echo "========== INSTALLING MINIKUBE =========="
if ! command -v minikube &> /dev/null; then
    curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64
fi

minikube version

echo "========================================"
echo "Choose Minikube Start Option:"
echo "1) Start with default resources"
echo "2) Start with custom MEMORY and CPU"
read -p "Enter option (1 or 2): " OPTION

if [[ "$OPTION" == "2" ]]; then
    read -p "Enter Memory in MB (e.g., 4096): " MEMORY
    read -p "Enter CPU count (e.g., 2): " CPUS

    if [[ -z "$MEMORY" || -z "$CPUS" ]]; then
        echo "Invalid input. Exiting."
        exit 1
    fi

    echo "Starting Minikube with ${MEMORY}MB RAM and ${CPUS} CPUs..."
    minikube start --driver=docker --profile $PROFILE --memory=$MEMORY --cpus=$CPUS
else
    echo "Starting Minikube with default resources..."
    minikube start --driver=docker --profile $PROFILE
fi

echo "========== VALIDATING CLUSTER =========="
kubectl get nodes

echo "========== VERIFYING KUBELET (Inside Node) =========="
minikube ssh -p $PROFILE "sudo systemctl status kubelet --no-pager"

echo "========== INSTALLATION COMPLETE =========="
echo ""
echo "Useful Commands:"
echo "minikube stop -p $PROFILE"
echo "minikube delete -p $PROFILE"
echo "minikube profile list"
