# Kubeadm Installation Guide

This guide outlines the steps needed to set up a Kubernetes cluster using `kubeadm`.

## Prerequisites

- Internet access
- Azure account setup, below youtube video will help you
 ```
https://www.youtube.com/watch?v=byVPxyoMMPA&pp=ygUYYXp1cmUgZnJlZSBhY2NvdW50IHNldHVw
   ```
- 3 Azure VMs required, below youtube video will help you
```
https://www.youtube.com/watch?v=dP0vNd5K2x8&pp=ygUWaG93IHRvIGNyZWF0ZSBhenVyZSB2bdgGuwLSBwkJhwoBhyohjO8%3D
   ```

---

## Azure Setup
Note:
1. Expose port **6443** in the **Network setting** to allow worker nodes to join the cluster.
2. Required **Peerings** in the **Virstual Network** to allow VMs nodes to connect with each other.


## To do above setup, follow below provided steps

### Step 1: Create Virtual machines

1. **Log in to the portal.azure.com **:
    - Go to the **Virtual machines** using left side portal menu or you can just search in search bar.

2. **To create VM**:
    - Click to the **Create** and select first option **Virtual machines**.
	- After clicking you will see the page where
	- **Project details:**
	- **Subscription**, you have to create new **Resource group** like **K8s_cluster_setup**.
	- **Instance details:**
	- **Virtual machine name** provide name for VM, 1st VM - Master, 2nd - Wroker1 and 3rd Worker2.
	- **Region**: (Asia Pacific) Australia East, (Asia Pacific) Central India
	- **Availability options**: No infrastructure redundancy required
	- Run with Azure Spot discount: click the button to get discount, But its work 3-4 times
	- **Size**: select somthing Standard_D2ls_v5 - 2 vcpus, 4 GiB memory ($0.01571)
	- **Administrator account**
	- **Authentication type** - select *SSH public key* when you want to connect with local, provide **Key pair name** - for 1st VM - Master, 2nd - Wroker1 and 3rd Worker2.
	- **Authentication type** - select **Password** then,
	- **Username** - for 1st VM - master, 2nd - wroker1 and 3rd worker2. and use same password for all will help to remember
	- click to the Next - Disk button
	- In **OS disk** ->OS disk type -> select **Standard SSD (locally-redundant storage)**
	- click to the Next - Networking button
	- In **Network interface** -> Public IP -> click on **Create New** and then ok after that ip will create -> (new) Master-ip
	-> **Select inbound ports** -> select both "SSH (22), RDP (3389)"
	- click to the ""Review + create""
	- Post validation click to the ""Create""
	- Do it again and again to create 3 VM
	- Once VM ready -> Go to the **Virtual machines** using left side portal menu or you can just search in search bar.


3. **Add 6443 port in all 3 VMs inside networking**:
    - In the left menu , click on **Virtual machines**.
	- click on Master -> In left side under the Networking go and click on **Network settings**
	- master: scroll down and in right side click on **Create port rule** to **create Inbound port rule**
		- **Destination port ranges** -> 6443, **Priority** -> 250 **Name** -> inbound6443
	- worker: scroll down and in right side click on **Create port rule** to **create outbound port rule**
		- **Destination port ranges** -> 6443, **Priority** -> 250 **Name** -> outbound6443

4. **Create a Peerings**:
    - In the left menu , click on **Virtual networks**.
    - click the virtual network of master vm: (check in Virtual machine you will get the details)
      - After open new window, scroll down and click **Peerings**
		- click on Add
		- **Peering link name**: (e.g., `master-worker1`) -> for both local and remote
		- **Virtual network**: select worker1 network -> allow below 2
		Allow 'vnet-eastasia' to access 'vnet-australiaeast'
		Allow 'vnet-eastasia' to receive forwarded traffic from 'vnet-australiaeast'
		Allow 'vnet-australiaeast' to access 'vnet-eastasia'
		Allow 'vnet-australiaeast' to receive forwarded traffic from 'vnet-eastasia'
		- **Peering link name**: (e.g., `master-worker2`) -> for both local and remote
		- **Virtual network**: select worker2 network -> allow below 2

    - click the virtual network of any worker vm: (check in Virtual machine you will get the details)
      - After open new window, scroll down and click **Peerings**
		- click on Add		
		- **Peering link name**: (e.g., `worker-worker`) -> for both local and remote
		- **Virtual network**: select worker2 network -> allow below 2		
		Now connection stablised among all 3 VMs.


5. **connect VMs**:
    - In the left menu , click on **Virtual machine**.
	- click on Connect -> Connect
		- **now you can use SSH command to connect VM**:
		- **or you can direct connect with **Serial console**: 
		- or you can use any other option inside **More ways to connect**


---


## Execute on Both "Master" & "Worker" Nodes

1. **Disable Swap**: Required for Kubernetes to function correctly.
    ```bash
    sudo swapoff -a
    ```

2. **Load Necessary Kernel Modules**: Required for Kubernetes networking.
    ```bash
    cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    EOF

    sudo modprobe overlay
    sudo modprobe br_netfilter
    ```

3. **Set Sysctl Parameters**: Helps with networking.
    ```bash
    cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    EOF

    sudo sysctl --system
    lsmod | grep br_netfilter
    lsmod | grep overlay
    ```

4. **Install Containerd**:
    ```bash
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y containerd.io

    containerd config default | sed -e 's/SystemdCgroup = false/SystemdCgroup = true/' -e 's/sandbox_image = "registry.k8s.io\/pause:3.6"/sandbox_image = "registry.k8s.io\/pause:3.9"/' | sudo tee /etc/containerd/config.toml

    sudo systemctl restart containerd
    sudo systemctl status containerd
    ```

5. **Install Kubernetes Components**:
    ```bash
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gpg

    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl
    ```

## Execute ONLY on the "Master" Node

1. **Initialize the Cluster**:
    ```bash
    sudo kubeadm init
    ```

2. **Set Up Local kubeconfig**:
    ```bash
    mkdir -p "$HOME"/.kube
    sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
    sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config
    ```

3. **Install a Network Plugin (Calico)**:
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.0/manifests/calico.yaml
    ```

4. **Generate Join Command**:
    ```bash
    kubeadm token create --print-join-command
    ```

> Copy this generated token for next command.

---

## Execute on ALL of your Worker Nodes

1. Perform pre-flight checks:
    ```bash
    sudo kubeadm reset pre-flight checks
    ```

2. Paste the join command you got from the master node and append `--v=5` at the end:
    ```bash
    sudo kubeadm join <private-ip-of-control-plane>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash> --cri-socket 
    "unix:///run/containerd/containerd.sock" --v=5
    ```

    > **Note**: When pasting the join command from the master node:
    > 1. Add `sudo` at the beginning of the command
    > 2. Add `--v=5` at the end
    >
    > Example format:
    > ```bash
    > sudo <paste-join-command-here> --v=5
    > ```

---

## Verify Cluster Connection

**On Master Node:**

```bash
kubectl get nodes

```

   <img src="https://raw.githubusercontent.com/faizan35/kubernetes_cluster_with_kubeadm/main/Img/nodes-connected.png" width="70%">

---

## Verify Container Status on Worker Node
<img src="https://github.com/user-attachments/assets/c3d3732f-5c99-4a27-a574-86bc7ae5a933" width="70%">


