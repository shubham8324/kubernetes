#!/bin/bash

set -e

PROFILE="dsoc3"
MEMORY="4096"
CPUS="2"

echo "========== SYSTEM PREPARATION =========="
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

echo "========== INSTALLING DOCKER =========="
if ! command -v docker &> /dev/null
then
    sudo apt install -y docker.io
    sudo systemctl enable docker
    sudo systemctl start docker
fi

sudo usermod -aG docker $USER || true
newgrp docker <<EOF
echo "Docker group refreshed"
EOF

docker --version
docker run hello-world || true

echo "========== INSTALLING kubectl =========="
if ! command -v kubectl &> /dev/null
then
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
fi

kubectl version --client

echo "========== INSTALLING MINIKUBE =========="
if ! command -v minikube &> /dev/null
then
    curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64
fi

minikube version

echo "========== STARTING MINIKUBE CLUSTER =========="

if minikube profile list | grep -q "$PROFILE"; then
    echo "Profile exists. Ensuring it's running..."
    minikube start --driver=docker --profile $PROFILE --memory=$MEMORY --cpus=$CPUS
else
    minikube start --driver=docker --profile $PROFILE --memory=$MEMORY --cpus=$CPUS
fi

echo "========== VALIDATING CLUSTER =========="
kubectl get nodes

echo "========== CHECKING KUBELET INSIDE NODE =========="
minikube ssh -p $PROFILE "sudo systemctl status kubelet --no-pager"

echo "========== DONE =========="
echo ""
echo "Useful Commands to stop & DELETE minikube"
echo "#minikube stop -p $PROFILE"
echo "#minikube delete -p $PROFILE"
echo "minikube profile list"
