Below is a single production-ready bootstrap script you can run on a fresh Ubuntu 24.04 machine over SSH.

It will:

Prepare system

Install Docker

Install kubectl

Install Minikube

Start cluster (dsoc3)

Validate cluster

Verify kubelet inside node

It is idempotent-safe and stops on failure.

✅ Usage

On your local machine:

ssh user@remote-host 'bash -s' < install_minikube_stack.sh


Or copy it to server and run:

chmod +x install_minikube_stack.sh
./install_minikube_stack.sh
