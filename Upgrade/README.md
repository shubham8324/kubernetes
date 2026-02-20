# 🚀 Production-Grade Kubernetes Upgrade Runbook

**Self-Managed kubeadm \| HA Multi-Cluster \| Sequential Minor Upgrades
(1.29 → 1.30 → 1.31)**

------------------------------------------------------------------------

## Executive Summary

Kubernetes upgrades are distributed system state transitions --- not
package updates.

In HA environments (3+ control-plane, quorum-based etcd), upgrades
affect:

-   API server consistency
-   etcd quorum stability
-   CNI dataplane behavior
-   Stateful workload integrity
-   Autoscaling behavior

This runbook provides a reversible, observable, production-safe upgrade
strategy designed for senior engineers operating real-world clusters.

------------------------------------------------------------------------

# Architecture Overview

## Assumptions

  Component       Design
  --------------- -------------------------
  Control Plane   3 nodes minimum
  etcd            quorum-based
  Workers         Rolling upgrade
  Upgrade Model   Sequential minor only

------------------------------------------------------------------------

# PHASE 0 --- Change Control

-   Freeze Changes
-   Announce change window
-   Plan rollback
-   Check node access
-   Confirm etcd backup policy

⚠️ Nothing technical begins before this phase completes.

------------------------------------------------------------------------

# PHASE 1 --- Technical Readiness

## Confirm Current State
```bash
kubectl version
kubectl get nodes -o wide
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
```
- If any deprecated APIs exist → STOP and migrate.
- If Output Exists: We must fix that before upgrade.
- It will show something like:
> group="policy",version="v1beta1"
- If something appears → we migrate those manifests before upgrade.
## Component Compatibility

Validate versions for:
-   CNI version
-   CSI drivers
-   Ingress controller
-   Metrics Server
-   Cluster Autoscaler

> Commands
```bash
Identify which CNI you use: then check the version

kubectl -n kube-system get pods
kubectl -n kube-system get pods -l k8s-app=calico-node -o jsonpath='{.items[0].spec.containers[0].image}'

Identify which CSI:
kubectl get csidrivers
kubectl get pv
kubectl get sc -o yaml


kubectl get pods -A | grep -i ingress
kubectl get pods -n kube-system | grep metrics
kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].spec.containers[0].image}'

````

## etcd Health

> Check etcd image and endpoint health before proceeding.
```bash
kubectl -n kube-system exec -it $(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].metadata.name}') -- etcdctl endpoint health

kubectl -n kube-system exec -it $(kubectl -n kube-system get pod -l component=etcd -o jsonpath='{.items[0].metadata.name}') -- \
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

sudo apt update
sudo apt install -y etcd-client

which etcdctl

correct output - /usr/bin/etcdctl

sudo -i

ETCDCTL_API=3 /usr/bin/etcdctl snapshot save /root/etcd-pre-1.30.db \
--endpoints=https://127.0.0.1:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key

or

ETCDCTL_API=3 etcdctl snapshot save /root/etcd-pre-1.30.db

Then verify –
ETCDCTL_API=3 etcdctl snapshot status /root/etcd-pre-1.30.db

## Export Baseline State

kubectl get nodes -o wide > before-nodes.txt
kubectl get pods -A -o wide > before-pods.txt
kubectl get deployments -A > before-deployments.txt
kubectl get statefulsets -A > before-statefulsets.txt
kubectl get ds -A > before-daemonsets.txt
kubectl get sc > before-storageclasses.txt
kubectl get pv > before-pv.txt

## Validate PDBs

kubectl get pdb -A

If empty → fine.
Calico controller can tolerate 1 pod disruption.

## Confirm Monitoring

Ensure visibility for:

-   API server latency
-   Node health
-   Restart spikes
-   etcd health

```bash
kubectl get nodes
kubectl get pods -A
```

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

1.  Update repo with target version

```bash
pt-cache madison kubeadm
cat /etc/apt/sources.list.d/kubernetes.list
sudo sed -i 's/v1.29/v1.30/g' /etc/apt/sources.list.d/kubernetes.list
cat /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
apt-cache madison kubeadm | grep 1.30

```
3.  Install kubeadm target version
```bash
sudo apt-get install -y kubeadm=1.30.x-*
kubeadm version

```
5.  kubeadm upgrade plan
```bash
sudo kubeadm upgrade plan
```
6.  kubeadm upgrade apply
```bash
sudo kubeadm upgrade apply v1.30.x
```
7.  Upgrade kubelet + kubectl
```bash
sudo apt-get install -y kubelet=1.30.14-1.1 kubectl=1.30.14-1.1
```
8.  Restart kubelet
```bash
sudo systemctl restart kubelet
```

9. Validate cluster health after each node.

10. Repeat per control-plane node (one by one)

------------------------------------------------------------------------

# PHASE 4 --- Worker Rolling Upgrade

Per worker node:

1.  Drain node
```bash
kubectl cordon <node>
kubectl drain <node> --ignore-daemonsets -delete-emptydir-data
```
2. Upgrade kubeadm
```bash
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt-get update
sudo apt-get install -y kubeadm=1.30.14-1.1

or

sudo apt-get install -y kubeadm=1.30.14-1.1 --allow-downgrades --allow-change-held-packages

```
> kubeadm version
- Must show v1.30.14

3.  kubeadm upgrade node
```bash
sudo kubeadm upgrade node
```
4.  Upgrade kubelet
```bash
sudo apt-get install -y kubelet=1.30.14-1.1 kubectl=1.30.14-1.1
```
5.  Restart kubelet
```bash
sudo systemctl restart kubelet
```
6.  kubectl uncordon <node>
```bash
kubectl uncordon worker
```
7. Validate pods rescheduled cleanly
```bash
kubectl get nodes
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
kubectl get pods -A
kubectl get svc -A
kubectl get pods -n kube-system
kubectl describe node master
kubectl describe node worker
kubectl get events -A --sort-by=.lastTimestamp


sudo ETCDCTL_API=3 /usr/bin/etcdctl \
--endpoints=https://127.0.0.1:2379 \
--cacert=/etc/kubernetes/pki/etcd/ca.crt \
--cert=/etc/kubernetes/pki/etcd/server.crt \
--key=/etc/kubernetes/pki/etcd/server.key \
endpoint health

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
