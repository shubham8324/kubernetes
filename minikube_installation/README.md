# Minikube Bootstrap -- Ubuntu 24.04

Production-ready bootstrap script to provision a local Kubernetes
environment using **Minikube (Docker driver)** on a fresh Ubuntu 24.04
machine.

------------------------------------------------------------------------

## Overview

This script performs the following:

-   System preparation (packages + updates)
-   Docker installation and configuration
-   kubectl installation
-   Minikube installation
-   Cluster creation (`dsoc3` profile)
-   Cluster validation
-   kubelet verification inside the Minikube node

The script is:

-   Idempotent (safe to re-run)
-   Stops on failure (`set -e`)
-   Designed for SSH execution
-   Architecturally correct (does not install kubelet on host)

------------------------------------------------------------------------

## Architecture Clarification

-   **Minikube** → Local single-node Kubernetes cluster\
-   **kubectl** → Kubernetes CLI client (runs on host)\
-   **kubelet** → Node agent (runs inside Minikube node)\
-   You do NOT manually install kubelet on the host.

------------------------------------------------------------------------

## Prerequisites

### System Requirements

-   Ubuntu 24.04 (fresh install recommended)
-   Minimum:
    -   2 vCPU
    -   4GB RAM
    -   20GB disk
-   Internet connectivity

### If Running in Cloud VM

Ensure:

-   Instance has at least 2 CPU / 4GB RAM
-   No restrictive container runtime policies
-   Security group/firewall allows outbound internet access

------------------------------------------------------------------------

## Installation Methods

### Option 1 --- Direct SSH Execution (Recommended)

``` bash
ssh user@remote-host 'bash -s' < install_minikube_stack.sh
```

------------------------------------------------------------------------

### Option 2 --- Copy & Execute on Server

``` bash
chmod +x install_minikube_stack.sh
./install_minikube_stack.sh
```

------------------------------------------------------------------------

## What the Script Does Internally

### 1. System Preparation

-   Updates OS
-   Installs base dependencies

### 2. Docker Installation

-   Installs `docker.io`
-   Enables and starts service
-   Adds user to docker group
-   Validates with `hello-world`

### 3. kubectl Installation

-   Downloads latest stable binary
-   Installs to `/usr/local/bin`

### 4. Minikube Installation

-   Downloads latest release
-   Installs globally

### 5. Cluster Creation

Creates profile:

    dsoc3

Allocates:

-   4GB Memory
-   2 CPUs
-   Docker driver

### 6. Validation

``` bash
kubectl get nodes
```

Expected:

    dsoc3   Ready   control-plane

### 7. kubelet Verification (Correct Layer)

``` bash
minikube ssh -p dsoc3
sudo systemctl status kubelet
```

This confirms kubelet runs inside the Minikube node, not on the host.

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

Check cluster status:

``` bash
minikube status -p dsoc3
```

------------------------------------------------------------------------

## Troubleshooting

### Docker Permission Issues

If you see permission denied errors:

``` bash
newgrp docker
```

Or re-login to refresh group membership.

------------------------------------------------------------------------

### Cluster Not Starting

Check:

``` bash
minikube logs -p dsoc3
docker ps
```

------------------------------------------------------------------------

### kubectl Not Connecting

Verify context:

``` bash
kubectl config current-context
```

Should show:

    dsoc3

If not:

``` bash
minikube profile dsoc3
```

------------------------------------------------------------------------

## Reset / Clean Install

Completely wipe environment:

``` bash
minikube delete --all --purge
```

Optional full Docker cleanup:

``` bash
sudo systemctl stop docker
sudo rm -rf /var/lib/docker
```

------------------------------------------------------------------------

## Version Verification

Check installed versions:

``` bash
docker --version
kubectl version --client
minikube version
kubectl get nodes
```

------------------------------------------------------------------------

## Security Considerations

-   Docker group grants root-equivalent privileges.
-   Do not run on shared production servers.
-   This setup is for local development, testing, and learning.

------------------------------------------------------------------------

## Intended Use Cases

-   Kubernetes learning
-   SRE lab environments
-   CI experimentation
-   API testing
-   Local deployment simulation

Not intended for:

-   Production workloads
-   Multi-node HA clusters
-   Enterprise-grade orchestration
