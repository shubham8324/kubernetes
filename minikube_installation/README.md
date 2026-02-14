# Minikube Bootstrap --- Ubuntu 24.04

Production-ready bootstrap script to provision a local Kubernetes
environment using **Minikube (Docker or None driver)** on Ubuntu 24.04.

------------------------------------------------------------------------

## Overview

This script provisions a complete single-node Kubernetes lab with:

-   System preparation (updates + base packages)
-   Swap disable (mandatory for Kubernetes)
-   Docker installation (if Docker driver selected)
-   kubectl installation
-   Minikube installation
-   Cluster creation using selected driver
-   Profile-based cluster management (`dsoc3`)
-   Cluster validation & status checks
-   Azure VM exposure guidance

The script:

-   Stops on failure (`set -e`)
-   Is safe to re-run
-   Supports Docker and None drivers
-   Supports custom CPU and memory allocation

------------------------------------------------------------------------

## Supported Drivers

  Driver   Description
  -------- -------------------------------------------------------
  docker   Runs Kubernetes inside Docker container
  none     Runs Kubernetes directly on host (VM/Bare Metal mode)

------------------------------------------------------------------------

## Usage

### Default (Docker driver)

``` bash
bash minikube.sh
```

### Custom CPU & Memory (Docker driver)

``` bash
bash minikube.sh 4096 2 docker
```

### None Driver (VM Mode)

``` bash
bash minikube.sh "" "" none
```

Format:

``` bash
bash minikube.sh <memory_mb> <cpus> <driver>
```

Driver values:

    docker
    none

------------------------------------------------------------------------

## What the Script Configures

### 1️⃣ System Preparation

-   Updates OS packages
-   Installs curl, wget, conntrack, certificates
-   Disables swap permanently

### 2️⃣ Docker (Docker Driver Only)

-   Installs docker.io
-   Enables and starts service
-   Adds user to docker group

⚠ Logout/login may be required after Docker install.

### 3️⃣ kubectl

-   Installs latest stable binary
-   Places in `/usr/local/bin`

### 4️⃣ Minikube

-   Installs latest release
-   Starts cluster with selected driver
-   Applies profile: `dsoc3`

### 5️⃣ Validation

``` bash
kubectl get nodes
minikube status -p dsoc3
```

Expected:

    dsoc3   Ready   control-plane

------------------------------------------------------------------------

## Architecture Clarification

Host VM ↓ Minikube Profile (dsoc3) ↓ Single Kubernetes Node ↓ Control
Plane + Kubelet

-   kubelet runs inside Minikube node
-   kubectl runs on host
-   No manual kubelet installation required

------------------------------------------------------------------------

## Azure VM Network Access (Prometheus Example)

If exposing services externally:

### 1️⃣ Add Azure NSG Inbound Rule

Azure Portal → VM → Networking → Add inbound rule:

-   Protocol: TCP
-   Port: 9090 or 30090
-   Action: Allow

------------------------------------------------------------------------

### 2️⃣ Port Forward (Optional)

``` bash
kubectl port-forward -n monitoring svc/prometheus-service 9090:9090 --address 0.0.0.0
```

or

``` bash
kubectl port-forward -n monitoring svc/prometheus-service 30090:9090 --address 0.0.0.0
```

------------------------------------------------------------------------

### 3️⃣ Verify Port Listening

``` bash
sudo ss -tulnp | grep 9090
sudo ss -tulnp | grep 30090
```

------------------------------------------------------------------------

### 4️⃣ UFW Firewall (If Active)

``` bash
sudo ufw status
sudo ufw allow 9090/tcp
sudo ufw allow 30090/tcp
```

------------------------------------------------------------------------

### 5️⃣ Get Public IP

``` bash
curl ifconfig.me
```

Access:

    http://VM_PUBLIC_IP:9090
    http://VM_PUBLIC_IP:30090

------------------------------------------------------------------------

## Operational Commands

Stop cluster:

``` bash
minikube stop -p dsoc3
```

Delete cluster:

``` bash
minikube delete -p dsoc3
```

List profiles:

``` bash
minikube profile list
```

Get cluster IP:

``` bash
minikube ip
minikube ip -p dsoc3
```

Open dashboard:

``` bash
minikube dashboard -p dsoc3
```

------------------------------------------------------------------------

## Troubleshooting

### Docker Permission Issue

``` bash
newgrp docker
```

or logout/login again.

------------------------------------------------------------------------

### None Driver kubectl Permission Fix

``` bash
sudo chown -R $USER:$USER ~/.kube ~/.minikube
```

------------------------------------------------------------------------

### Cluster Logs

``` bash
minikube logs -p dsoc3
```

------------------------------------------------------------------------

## Reset Environment

``` bash
minikube delete --all --purge
```

------------------------------------------------------------------------

## Security Considerations

-   Docker group grants root-equivalent privileges.
-   Prometheus has no authentication by default.
-   Do not expose monitoring tools publicly without protection.
-   This environment is for lab/testing --- not production workloads.

------------------------------------------------------------------------

## Intended Use Cases

-   Kubernetes learning
-   SRE lab environments
-   Cloud VM experimentation
-   Monitoring stack testing
-   CI/CD experimentation
