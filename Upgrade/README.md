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
-   Admission webhooks
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
  etcd            Stacked, quorum-based
  Workers         Rolling upgrade
  Upgrade Model   Sequential minor only
  Version Skew    kubelet ≤ control-plane

------------------------------------------------------------------------

# PHASE 0 --- Change Control

-   Freeze CI/CD pipelines
-   Disable GitOps auto-sync
-   Announce change window
-   Assign rollback owner
-   Confirm node access
-   Confirm etcd backup policy

⚠️ Nothing technical begins before this phase completes.

------------------------------------------------------------------------

# PHASE 1 --- Technical Readiness

## Confirm Current State

kubectl version\
kubectl get nodes -o wide

## Version Path

Allowed: 1.29 → 1.30 → 1.31

Never skip minor versions.

  Component                          Allowed Skew
  ---------------------------------- ----------------
  kubelet                            1 minor behind
  kubelet newer than control-plane   Not allowed
  kubectl                            ±1 minor

## Deprecated API Detection

Runtime check: kubectl get --raw /metrics \| grep
apiserver_requested_deprecated_apis

Static scan: kubectl get all -A -o yaml \| grep apiVersion \| grep
v1beta\
kubectl get crd -o yaml \| grep v1beta

If any deprecated APIs exist → STOP and migrate.

## Component Compatibility

Validate versions for:

-   CNI
-   CSI drivers
-   Ingress controller
-   Metrics Server
-   Cluster Autoscaler

## etcd Health

Check etcd image and endpoint health before proceeding.

------------------------------------------------------------------------

# PHASE 2 --- Safety Preparation

## etcd Snapshot

ETCDCTL_API=3 etcdctl snapshot save /root/etcd-pre-1.30.db\
ETCDCTL_API=3 etcdctl snapshot status /root/etcd-pre-1.30.db

## Export Baseline State

kubectl get nodes -o wide \> before-nodes.txt\
kubectl get pods -A -o wide \> before-pods.txt\
kubectl get deployments -A \> before-deployments.txt\
kubectl get sc \> before-storageclasses.txt\
kubectl get pv \> before-pv.txt

## Validate PDBs

kubectl get pdb -A

## Confirm Monitoring

Ensure visibility for:

-   API server latency
-   Node health
-   Restart spikes
-   etcd health

## Rollback Plan (Stacked etcd)

1.  Stop kubelet\
2.  Move etcd data directory\
3.  Restore snapshot\
4.  Fix permissions\
5.  Start kubelet

------------------------------------------------------------------------

# PHASE 3 --- Control Plane Upgrade

Per control-plane node (sequential):

1.  Update repo
2.  Install kubeadm target version
3.  kubeadm upgrade plan
4.  kubeadm upgrade apply
5.  Upgrade kubelet + kubectl
6.  Restart kubelet

Validate cluster health after each node.

------------------------------------------------------------------------

# PHASE 4 --- Worker Rolling Upgrade

Per worker node:

1.  kubectl cordon `<node>`{=html}
2.  kubectl drain `<node>`{=html} --ignore-daemonsets
    --delete-emptydir-data
3.  Upgrade kubeadm
4.  kubeadm upgrade node
5.  Upgrade kubelet
6.  Restart kubelet
7.  kubectl uncordon `<node>`{=html}

Upgrade one worker at a time.

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

Observe for 24--48 hours.

------------------------------------------------------------------------

# PHASE 6 --- Next Minor Upgrade

Repeat entire process for:

1.30 → 1.31

Never assume safety across minor versions.

------------------------------------------------------------------------

# PHASE 7 --- Multi-Cluster Strategy

Upgrade order:

1.  Dev
2.  Staging
3.  Lowest traffic production
4.  Remaining production (staggered)

Never upgrade high-traffic clusters in parallel.

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

# Final Checklist

-   [ ] CI/CD frozen
-   [ ] etcd snapshot verified
-   [ ] Deprecated APIs cleared
-   [ ] Component compatibility confirmed
-   [ ] PDB audited
-   [ ] Control plane sequentially upgraded
-   [ ] Workers upgraded one-by-one
-   [ ] etcd health validated
-   [ ] 24-hour monitoring completed

------------------------------------------------------------------------

Clusters fail quietly. Monitor longer than you think necessary.
