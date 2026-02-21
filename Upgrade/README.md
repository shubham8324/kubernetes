# 🚀 Production-Grade Kubernetes Upgrade Runbook

**Self-Managed kubeadm \| HA Multi-Cluster \| Sequential Minor Upgrades
(1.29 → 1.30 → 1.31)**

------------------------------------------------------------------------

## Executive Summary

Kubernetes upgrades are distributed system state transitions --- not package updates.

This runbook provides a reversible, observable, production-safe upgrade strategy designed for senior engineers operating real-world clusters.

------------------------------------------------------------------------

# Architecture Overview (Assumptions)

| Component      | Design                 |
|---------------|------------------------|
| Control Plane | 3 nodes minimum        |
| etcd          | quorum-based           |
| Workers       | Rolling upgrade        |
| Upgrade Model | Sequential minor only  |


### Upgrade Implication:

1️⃣ Control Plane
- Sequential upgrade (one control-plane node at a time)
- etcd quorum intact (minimum 2/3 members available)
- etcd snapshot taken before upgrade

2️⃣ Worker Nodes
- Upgrade one worker at a time
- kubectl drain & cordon mandatory before upgrade
- Respect PodDisruptionBudgets (PDBs - safety during maintenance)
- Ensure workloads have ≥2 replicas for zero-downtime

3️⃣ Version Compatibility
- Sequential minor version upgrade only (no version skipping)
- CNI plugin supports target Kubernetes version (Sample)
```bash
https://docs.tigera.io/calico-enterprise/latest/getting-started/compatibility#kubernetes-kubeadm
https://docs.cilium.io/en/stable/network/kubernetes/compatibility/
```
- CSI driver supports target Kubernetes version
```bash
https://kubernetes.io/blog/2019/01/15/container-storage-interface-ga/
```
- Ingress controller or API Gateway compatibility verified - check officially website for version support.
- Metrics API / metrics-server compatibility verified
```bash
https://github.com/kubernetes-sigs/metrics-server#compatibility-matrix
```
- CRD-based components validated against target version

4️⃣ Safety Controls
- Backup critical cluster state before control-plane upgrade
- No upgrade if any core dependency (CNI/CSI/Ingress) is incompatible

## Architectural Risk Assumptions
- etcd quorum loss = cluster outage
- Single control plane = unacceptable production design
- No PDBs = upgrade risk
- CNI incompatibility = networking failure
- CSI mismatch = storage attach/detach failure
- 
------------------------------------------------------------------------

# PHASE 0 --- Change Control

-   Freeze Changes
-   Announce change window
-   Plan rollback
-   Check node access
-   Confirm etcd backup

⚠️ Nothing technical begins before this phase completes.

------------------------------------------------------------------------

# PHASE 1 --- Technical Readiness

## Confirm Current State
```bash
kubectl version

kubectl get pods -A
kubectl get nodes -o wide

---API health
kubectl get --raw='/readyz?verbose'
kubectl get --raw='/livez?verbose'

----Runtime validation
containerd --version
crictl info
systemctl status containerd

kubectl config view

kubectl -n kube-system get cm kubeadm-config -o yaml
cat /etc/containerd/config.toml | grep SystemdCgroup
- If SystemdCgroup=false on systemd host → kubelet instability.

---Check certs expiry
```
## Version Path

> Allowed: 1.29 → 1.30 → 1.31

Never skip minor versions.

  Component                          Allowed Skew
  ---------------------------------- ----------------
  kubelet                            1 minor behind
  kubelet newer than control-plane   Not allowed
  kubectl                            ±1 minor

## Deprecated API Detection
```bash
Runtime check: 
kubectl get --raw /metrics | grep apiserver_requested_deprecated_apis

Static scan:
kubectl get all -A -o yaml | grep apiVersion | grep v1beta
kubectl get crd -o yaml | grep v1beta

Kube check:
cat /etc/kubernetes/manifests/kube-apiserver.yaml
kubectl -n kube-system get cm kube-proxy -o yaml


```
- If any deprecated APIs exist → STOP and migrate.
- It will show something like:
> group="policy",version="v1beta1"
- If Output Exists: We must fix that before upgrade.



## etcd Health

> Check etcd image and endpoint health before proceeding.
```bash

ETCDCTL_API=3 etcdctl endpoint health
ETCDCTL_API=3 etcdctl member list
ETCDCTL_API=3 etcdctl endpoint status --write-out=table


export ETCDCTL_API=3
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key


kubectl -n kube-system exec -it <etcd-pod> -- \
sh -c "ETCDCTL_API=3 etcdctl \
--endpoints=https://127.0.0.1:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key \
endpoint health"
```
> If any of these fail → STOP.

------------------------------------------------------------------------

# PHASE 2 --- Safety Preparation

## etcd Snapshot
```bash
sudo apt update
sudo apt install -y etcd-client
which etcdctl
correct output -
/usr/bin/etcdctl


ETCDCTL_API=3 etcdctl \
--endpoints=https://127.0.0.1:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key \
snapshot save /root/etcd-pre-1.30.db

```

Then verify –
```bash
ETCDCTL_API=3 etcdctl snapshot status /root/etcd-pre-1.30.db --write-out=table

scp /root/etcd-pre-1.30.db backup-server:/secure-path/
ls -lh /root/etcd-pre-1.30.db
```

## Static Pod Manifest and PKI Backup
```bash
/etc/kubernetes/manifests/*
sudo tar -czvf /root/k8s-manifests-backup-$(date +%F).tar.gz /etc/kubernetes/manifests/

/etc/kubernetes/pki/
sudo tar -czvf /root/k8s-pki-backup-$(date +%F).tar.gz /etc/kubernetes/pki/
```

## Export Baseline State
```bash
kubectl get nodes -o wide > before-nodes.txt
kubectl get pods -A -o wide > before-pods.txt
kubectl get deployments -A > before-deployments.txt
kubectl get statefulsets -A > before-statefulsets.txt
kubectl get ds -A > before-daemonsets.txt
kubectl get sc > before-storageclasses.txt
kubectl get pv > before-pv.txt
```

## Confirm Monitoring

Ensure visibility for:

-   API server latency
-   Node health
-   Restart spikes
-   etcd health


## Rollback Plan (Stacked etcd)

1.  Stop kubelet
2.  Move etcd data directory
3.  Restore snapshot
4.  Fix permissions
5.  Start kubelet

```Bash
🔴 Step 1 — Stop kubelet
sudo systemctl stop kubelet

This stops static pods (including etcd).

🔴 Step 2 — Move Existing etcd Data Directory
grep data-dir /etc/kubernetes/manifests/etcd.yaml
move
sudo mv /var/lib/etcd /var/lib/etcd-backup-$(date +%F)

🔴 Step 3 — Restore Snapshot
sudo ETCDCTL_API=3 /usr/bin/etcdctl snapshot restore /root/etcd-pre-1.30.db \
--data-dir=/var/lib/etcd

🔴 Step 4 — Fix Permissions
sudo chown -R etcd:etcd /var/lib/etcd

🔴 Step 5 — Start kubelet
sudo systemctl start kubelet

```

> Only when Phase 2 is complete → upgrade allowed.

------------------------------------------------------------------------

# PHASE 3 --- Control Plane Upgrade

Per control-plane node (sequential):

0.  Drain node(if anything running)
```bash
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

kubectl get pods -A -o wide | grep <worker-node>
```

1.  Update repo with target version

```bash
kubectl version
kubeadm version
ls /etc/apt/sources.list.d/


sudo cp /etc/apt/sources.list.d/kubernetes.list \
/etc/apt/sources.list.d/kubernetes.list.bak

sudo rm /etc/apt/sources.list.d/kubernetes.list


sudo mkdir -p /etc/apt/keyrings


curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  
  
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' \
| sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update

apt-cache madison kubeadm | grep 1.30

cat /etc/apt/sources.list.d/kubernetes.list

```
3.  Install kubeadm target version
```bash

sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm=1.30.14-1.1
sudo apt-mark hold kubeadm
kubeadm version
```

4. Pre-pull Images
```bash
sudo kubeadm config images pull
```

5.  kubeadm upgrade plan

A. For first control-plane:
```bash
sudo kubeadm upgrade plan
```

 kubeadm upgrade apply (Only First control-plan)
```bash
sudo kubeadm upgrade apply v1.30.14
```

B. For remaining control-plane nodes:
```bash
sudo kubeadm upgrade plan
```


7.  Upgrade kubelet + kubectl
```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.30.14-1.1 kubectl=1.30.14-1.1
sudo apt-mark hold kubelet kubectl
```
8.  Restart kubelet
```bash
sudo systemctl restart kubelet

systemctl status kubelet
journalctl -u kubelet -xe

kubectl version
kubelet version

kubectl uncordon <control-plane-node>

```

9. Validate cluster health after each node.
```bash
ls /etc/kubernetes/manifests/
kubectl get nodes -o wide
kubectl describe node <node-name>
kubectl get pods -n kube-system -o wide
kubectl get componentstatuses
kubectl get --raw='/livez?verbose'
kubectl get --raw='/readyz?verbose'
ETCDCTL_API=3 etcdctl endpoint health
kubectl get pods -A
kubectl get deploy -A
kubectl get svc -A
kubectl top nodes
kubectl top pods -A
kubectl get events -A --sort-by='.lastTimestamp'
```

10. Repeat per control-plane node (one by one)

------------------------------------------------------------------------

# PHASE 4 --- Worker Rolling Upgrade

Per worker node:
0.  Drain worker node
```bash
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

kubectl get pods -A -o wide | grep <worker-node>
```

1.  Update repo with target version

```bash
ls /etc/apt/sources.list.d/


sudo cp /etc/apt/sources.list.d/kubernetes.list \
/etc/apt/sources.list.d/kubernetes.list.bak

sudo rm /etc/apt/sources.list.d/kubernetes.list


sudo mkdir -p /etc/apt/keyrings


curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  
  
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' \
| sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt update

apt-cache madison kubeadm | grep 1.30

cat /etc/apt/sources.list.d/kubernetes.list

```
2.  Install kubeadm target version
```bash

sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm=1.30.14-1.1
sudo apt-mark hold kubeadm
kubeadm version
```

3.  kubeadm upgrade node
```bash
sudo kubeadm upgrade node

```

4.  Upgrade kubelet + kubectl
```bash
sudo apt-mark unhold kubelet kubectl
sudo apt-get install -y kubelet=1.30.14-1.1 kubectl=1.30.14-1.1
sudo apt-mark hold kubelet kubectl
```

5.  Restart kubelet
```bash
sudo systemctl restart kubelet
sudo systemctl status kubelet

kubectl get node <worker> -o yaml | grep kubeletVersion
kubectl uncordon <worker>
```

6. Validate cluster health after each node.
```bash
kubectl get nodes -o wide
kubectl describe node <node-name>
kubectl get pods -n kube-system -o wide
kubectl get componentstatuses
kubectl get --raw='/livez?verbose'
kubectl get --raw='/readyz?verbose'
ETCDCTL_API=3 etcdctl endpoint health
kubectl get pods -A
kubectl get deploy -A
kubectl get svc -A
kubectl top nodes
kubectl top pods -A
kubectl get events -A --sort-by='.lastTimestamp'
```

> Upgrade one worker at a time.

------------------------------------------------------------------------

# PHASE 5 --- Post-Upgrade Validation

Validate:

-   All nodes Ready
-   kube-system healthy
-   DNS resolution
-   Ingress routing
-   PVC mounts
-   HPA scaling
-   No CrashLoopBackOff
-   etcd endpoint health

```bash
kubectl get nodes
kubectl get pods -n kube-system
kubectl get componentstatuses   # (deprecated but useful quick view)
ETCDCTL_API=3 etcdctl endpoint health
kubectl get nodes -o wide
systemctl status kubelet
journalctl -u kubelet -n 50
kubectl get pods -A | grep -v Running
kubectl get deploy -A
kubectl get statefulset -A
kubectl get daemonset -A
kubectl get hpa -A
kubectl get pvc -A
kubectl get pv
kubectl get ingress -A
kubectl top nodes
kubectl top pods -A
kubectl get events -A --sort-by=.lastTimestamp
kubectl version
kubectl get --raw /metrics | grep deprecated
kubectl get crd

```
> Observe for 24--48 hours.

------------------------------------------------------------------------

# PHASE 6 --- Next Minor Upgrade

Repeat entire process for:

1.30 → 1.31

> Never assume safety across minor versions.

------------------------------------------------------------------------

# PHASE 7 --- Multi-Cluster Strategy

Upgrade order:

1.  Dev
2.  Staging
3.  production
4.  DR

> Never upgrade high-traffic clusters in parallel.

------------------------------------------------------------------------

# Risk Matrix

  Risk                     Impact     Mitigation
  ------------------------ ---------- --------------------------
  Deprecated API break     High       Scan before upgrade
  etcd corruption          Critical   Snapshot + test restore
  PDB misconfig            High       Audit before drain
  CNI incompatibility      High       Validate version support
  Version skew violation   High       Respect skew policy


------------------------------------------------------------------------

> Clusters fail quietly. Monitor longer than you think necessary.
