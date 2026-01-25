## ✅ What is Kubernetes (K8s)
- **Kubernetes** is an **open-source container orchestration platform**.
- It automates **deployment, scaling, load balancing, and management** of containers.
- It runs containers on **virtual machines, physical servers, or cloud**.
- Supported by **all major cloud providers** (AWS, Azure, GCP).
## 🕰️ Short History 
- Google internally used **Borg** (later **Omega**) to manage large-scale applications.
- In **2014**, Google open-sourced Kubernetes.
- Written in **Go (Golang)**.
- Donated to **CNCF (Cloud Native Computing Foundation)**.
- Commonly called **K8s** (8 letters between K and S).
## ⭐ Key Features of Kubernetes (Simple & Practical)
### 1️⃣ Orchestration
- Manages **thousands of containers** across multiple nodes automatically.
### 2️⃣ Auto Scaling
- **Horizontal Pod Autoscaling (HPA):** Scale pods up/down.
- **Vertical Scaling:** Increase CPU/Memory.
### 3️⃣ Self-Healing
- Restarts failed pods.
- Replaces unhealthy containers.
- Reschedules pods if a node fails.
### 4️⃣ Load Balancing
- Automatically distributes traffic across pods using **Services**.
### 5️⃣ Platform Independent
- Works on:
    - Cloud
    - Virtual machines
    - Bare metal servers

### 6️⃣ Fault Tolerance
- Handles:
    - Pod failure
    - Node failure
    - Container crash

### 7️⃣ Rollback & Rollout
- Roll back to a **previous stable version** if deployment fails.
- Supports **zero-downtime deployments**.
### 8️⃣ Health Monitoring
- Uses:
    - **Liveness probes**
    - **Readiness probes**
    - **Startup Probe**

- Ensures only healthy pods receive traffic.
### 9️⃣ Batch & Job Execution
- Supports:
    - One-time jobs
    - Scheduled jobs (CronJobs)
    - Parallel & sequential execution

---

- [ ] Important Details: 
**Container:** A lightweight package that runs an application with all its dependencies in isolation.

**Containerisation:** The process of packaging an application and its dependencies into a container.

**Docker:** A tool used to build, run, and manage containers.

**Docker Hub:** A public registry where container images are stored and shared.

**Orchestration:** Automated management of multiple containers (start, scale, heal, load-balance).

**Kubernetes (K8s):** A container orchestration platform that manages containers across multiple machines. developed by Google, maintained by CNCF.

**Cluster:** A **cluster** is a group of machines (nodes) that work together as one system to run and manage applications.

---

- [ ] K8s architecture :
**Master (Control Plane):** Manages the Kubernetes cluster—handles API requests, schedules pods, maintains cluster state (API Server, Scheduler, Controller Manager, etcd).

**Worker Nodes:** Run the actual applications—host Pods and containers, managed by kubelet and kube-proxy, and provide compute resources.



Master:

1. **API Server:** Entry point of the cluster; interacts directly with the user (i.e we apply .yml or .json manifest to kube-api-server) 
2. **etcd: **Stores metadata and status of the cluster. (key-value-store) 
3. **Scheduler:** Assigns Pods to worker nodes based on resource availability and constraints. A scheduler watches for newly created pods that have no node assigned.
4. **Controller Manager:** Make sure the actual state of the cluster matches the desired state. 
Worker:

1. **kubelet:** Agent on each worker node that runs and manages Pods.
2. **kube-proxy:** Handles networking and load balancing for Services. Assign IP to each pod. 
3. **container runtime:** Runs on **worker nodes** → responsible for **running containers**
4. **Networking:** CNI plugins (Calico, Cilium), responsible for **Pod networking (IP, routing, network policies).**
---

🔑 Additional Important :

Kubernetes does **NOT build images** → Docker/Build tools do.

Kubernetes does **NOT store images** → Registries (Docker Hub, ECR).

The secret data on nodes is stored in tmpfs volume (tmps is a filesystem that keeps all files in virtual memory.) Everything in tmpfs is temporary in the sense that no files will be created on your hard drive.

**kubectl - **A command-line tool used by users to **interact with a Kubernetes cluster** (create, view, update, delete resources).

**kubeadm - **A tool used by administrators to **set up and manage a Kubernetes cluster** (initialize master and join worker nodes).

**Liveness Probe** – Checks if the container is alive; if it fails, Kubernetes **restarts** the container.

**Readiness Probe** – Checks if the container is ready to receive traffic; if it fails, traffic is **stopped** to the Pod.

**Startup Probe** – Checks if the application has started successfully; used for **slow-starting apps**.

**CoreDNS - **CoreDNS is the **DNS server of a Kubernetes cluster**; it resolves **Service and Pod names to IP addresses** so Pods can communicate using names instead of IPs. CoreDNS allows Pods to find and talk to each other using DNS names (like `myservice.default.svc.cluster.local`).



** Architecture of Kubernetes :**









![image.png](https://eraser.imgix.net/workspaces/fR2HqXW02CufT1c7rxGf/qIg1eEirBlR2rPCcuuET7nmCyCW2/image_VUxk5UYU0wtOy4uYijRqL.png?ixlib=js-3.8.0 "image.png")



![image.png](https://eraser.imgix.net/workspaces/fR2HqXW02CufT1c7rxGf/qIg1eEirBlR2rPCcuuET7nmCyCW2/image_OW4SNH3m6WNEfFv5eEVrk.png?ixlib=js-3.8.0 "image.png")

---



**🎯Controllers inside Controller Manager (common ones):**
- Node Controller – monitors node health
- Replication Controller – maintains replica count
- Deployment Controller – manages ReplicaSets
- ReplicaSet Controller – manages Pods
- Job Controller – manages Jobs
- CronJob Controller – manages CronJobs
- Endpoint/EndpointSlice Controller – updates service endpoints
- ServiceAccount Controller – manages service accounts

🧩Cloud-specific controllers:
- Node Controller – checks node status with cloud provider
- Route Controller – sets up cloud network routes
- Service Controller – creates cloud Load Balancers
- Volume Controller – manages cloud disks (EBS, Azure Disk, etc.)


---

```
Note: Now most prod environment using containerd

🔴Docker = full container platform (build, ship, run)
kubelet
  ↓
Docker Engine
  ↓
containerd
  ↓
runc

🟢containerd = lightweight container runtime (run only)
kubelet
  ↓ (CRI)
containerd
  ↓
runc

------------------------------
Docker world:
docker ps
docker images
docker logs

containerd world:
crictl ps
crictl images
crictl logs <container-id>
```
---

## 🟦 Pod
The **smallest deployable unit** in Kubernetes that runs **one or more containers** together.

---

## 🟦 Multiple Containers in a Pod
Containers in the same Pod **share network (IP/port) and storage** and work together (example: app + log sidecar).

🔹 1️⃣ Sidecar Pattern

A helper container that runs alongside the main app to provide **extra functionality** (logging, monitoring, config reload).

🔹 2️⃣ Init Container

A special container that **runs before the main application container** starts and performs **setup or preparation tasks**.

### And many more ....
---

## 🟦 Deployment
 A Kubernetes object used to **deploy, update, scale, and manage Pods** with features like rolling updates and rollback.

---

## 🟦 Replication Set
 Auto scaling and auto-healing.



---

## 🟦 Volume
A **Volume** is used to **store data for Pods** so that data is **not lost when containers restart**.

### 1️⃣ emptyDir -  
Use this when we want to share contents between multiple containers on the same pod .

- Temporary storage
- Created when Pod starts, deleted when Pod is removed
### 2️⃣ hostPath
Use this when we want to access the content of a pod/container from the host machine.

- Uses node’s local filesystem
- Mostly for **testing**
### 3️⃣ PersistentVolume (PV)
- Actual storage resource (disk, NFS, cloud disk)
- Created by admin or dynamically
### 4️⃣ PersistentVolumeClaim (PVC)
- Request for storage by a Pod
- Pod uses PVC, not PV directly
### 5️⃣ Cloud Volumes
- AWS EBS, Azure Disk, GCE PD
- Used in **cloud environments**
---

## 🟦 Service
A stable network endpoint that **exposes Pods** and provides **load balancing**.

### Types of Services:
- **ClusterIP:** is used for **internal Pod-to-Pod communication**.(service-name.namespace.svc.cluster.local)
- **NodePort:** exposes a Service on **every worker node’s IP** at a **fixed port** (range: `30000–32767`), so you can access it from **outside the cluster**. Exposes the service on the same port of each selected node in the cluster using NAT. 
- **LoadBalancer:** Exposes service using cloud load balancer
- **ExternalName:** Maps service to an external DNS name
- **Headless **– Creates several endpoints that are used to produce DNS records. Each DNS record is bound to a Pod. 
---

## 🟦 Ingress
Ingress is a Kubernetes resource that **manages external HTTP/HTTPS access** to services inside the cluster using **URLs and paths**.

## 🔹 Why Ingress is needed
- NodePort and LoadBalancer expose **one service at a time**
- Ingress allows **multiple services** using:
    - Same IP
    - Different **paths or domains**

---

## 🟦 Ingress Controller
**Ingress Controller:**
 An **Ingress Controller** is a component that **actually implements Ingress rules** by running a **reverse proxy / load balancer** inside the Kubernetes cluster.

👉 **Ingress = rules**
 👉 **Ingress Controller = engine that applies those rules**

---

## 🟦 ConfigMap (CM)
Stores **non-sensitive configuration data** (env variables, config files) used by Pods.

---

## 🟦 Secret
Stores **sensitive data** like passwords, tokens, and keys (base64 encoded).

---

## 🟦 Namespace
A logical separation inside a cluster to **organize and isolate resources** (dev, test, prod).

---

### How kubeadm work: 
1️⃣ **when you run**: kubeadm init

This command **creates the Kubernetes control plane (master)**.

### **2️⃣ Preflight Checks**
kubeadm first checks:

- Linux kernel settings
- Swap is disabled
- Ports are free (6443, etc.)
- container runtime is running
- Required images can be pulled
👉 If something is wrong, kubeadm **stops here**.

### **3️⃣ Pull Images (from registry.k8s.io)**
kubeadm downloads required images:

- kube-apiserver
- kube-scheduler
- kube-controller-manager
- etcd
### **4️⃣ Generate TLS Certificates**
kubeadm creates **security certificates** for :

- API Server
- etcd
- kubelet
- controller & scheduler
 And stored at "/etc/kubernetes/pki"

Note: 👉 This enables **secure communication (HTTPS)** inside the cluster.

### **5️⃣ Generate kubeconfig Files**
kubeadm generates config files for:

- admin
- kubelet
- controller-manager
- scheduler
And stored at "/etc/kubernetes/"

Note: 👉 These files tell components **how to talk to the API Server**.



### **6️⃣ Static Pod Manifests Created**
kubeadm creates YAML files for control-plane components:

- kube-apiserver
- etcd
- kube-scheduler
- kube-controller-manager
Stored at:

```
/etc/kubernetes/manifests
```
👉 These are **static pods**, not normal pods.

### **7️⃣ kubelet Starts Control Plane**
kubelet watches:

```
/etc/kubernetes/manifests
```
When kubelet sees these files:

- It starts containers using container runtime
- Control plane components start running
👉 **kubelet actually launches the master components**

### **8️⃣ Control Plane is Now Running**
These components are now live:

- API Server
- etcd
- Scheduler
- Controller Manager
👉 The cluster control plane is ready.

### **9️⃣ Deploy CoreDNS & kube-proxy**
kubeadm deploys:

- **CoreDNS** → cluster DNS
- **kube-proxy** → service networking
👉 These run as **normal pods** in the cluster.

### **🔟 Generate Node Bootstrap Token**
kubeadm creates:

- **join token**
- **CA cert hash**
👉 This allows **worker nodes to securely join** the cluster.



![image.png](https://eraser.imgix.net/workspaces/fR2HqXW02CufT1c7rxGf/qIg1eEirBlR2rPCcuuET7nmCyCW2/image_508odDY3ATZL9RFfGvQe1.png?ixlib=js-3.8.0 "image.png")



---

============> How components work

🔹 kubectl / User Request Flow (Control Plane)
kubectl / User
 → API Server
 → Authentication
 (cert / token / service-account)
 → Authorization (RBAC)
 (Role, ClusterRole, RoleBinding)
 → Admission Controllers
 (validate, mutate, enforce policy)
 → etcd
 (store object / desired state)



🔹 Pod Scheduling Flow
API Server
 → Scheduler
 → watches for Pods without nodeName
 → selects best Worker Node
 → API Server
 → updates Pod with nodeName



🔹 Desired State Reconciliation Flow
API Server
 → Controller Manager
 → watches cluster state
 → compares desired vs actual state
 → creates / updates / deletes objects
 → API Server
 → persists changes in etcd



🔹 Pod Creation on Worker Node
API Server
 → kubelet (on Worker)
 → reads PodSpec
 → calls Container Runtime (containerd)
 → pulls image
 → creates containers
 → calls CNI plugin
 → assigns Pod IP
 → sets up networking



🔹 Container Runtime Flow
kubelet
 → containerd
 → pull image from registry
 → create container
 → start container



🔹 Networking (CNI) Flow
kubelet
 → CNI (Calico / Cilium)
 → assign Pod IP
 → setup routes
 → apply network policies



🔹 Service & Traffic Flow (App Request)
Client / User
 → Service (ClusterIP / NodePort / LoadBalancer)
 → kube-proxy (iptables / IPVS)
 → Pod IP
 → Container (Application)
 → Response back to Client



🔹 Node Health Monitoring Flow
kubelet
 → API Server
 → updates node & pod status
 → Node Controller
 → detects NotReady node
 → reschedules Pods if needed



🧠 Ultra-short Memory Version
User → API Server → Auth → RBAC → Admission → etcd
API Server → Scheduler → Node selected
API Server → kubelet → containerd + CNI
Traffic → Service → kube-proxy → Pod → Container







