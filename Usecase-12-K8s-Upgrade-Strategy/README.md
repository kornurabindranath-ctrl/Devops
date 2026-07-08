# ⚙️ Kubernetes Upgrade Strategy — Zero-Downtime EKS Upgrade

![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazon-aws&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-1.35%20→%201.36-326CE5?logo=kubernetes&logoColor=white)
![eksctl](https://img.shields.io/badge/eksctl-cluster%20mgmt-4285F4)
![Status](https://img.shields.io/badge/Downtime-Zero-brightgreen)
![License](https://img.shields.io/badge/License-MIT-lightgrey)

This project demonstrates how to safely upgrade an Amazon EKS cluster in production without dropping a single request. It covers the full lifecycle — pre-upgrade validation, control plane upgrade, managed node group rotation, pod rescheduling under a PodDisruptionBudget, and post-upgrade verification — along with a rollback plan for when things don't go as expected.

**Core practices implemented:**

- ➤ Control plane upgrade (1.35 → 1.36)
- ➤ Managed node group upgrade via rolling replacement
- ➤ PodDisruptionBudget (PDB) enforcement
- ➤ Node cordon and drain
- ➤ Rolling pod rescheduling
- ➤ Cluster health validation
- ➤ Rollback planning

- ## 🏗️ Architecture

```mermaid
flowchart TD
    A[Internet] --> B[AWS Load Balancer - ELB]
    B --> C[Kubernetes Service]
    C --> D[NGINX Deployment - 3 Replicas]
    D --> E[Pod 1]
    D --> F[Pod 2]
    D --> G[Pod 3]
    E & F & G --> H[PodDisruptionBudget<br/>minAvailable: 2]
    H --> I[Worker Node-1 - v1.35]
    H --> J[Worker Node-2 - v1.35]
    I --> K[Amazon EKS Control Plane<br/>Kubernetes v1.35]
    J --> K
```

```mermaid
flowchart TD
    A[Pre-Upgrade Validation] --> B[Verify Cluster Health]
    B --> C[Verify EKS Add-on Compatibility]
    C --> D[Upgrade EKS Control Plane 1.35 → 1.36]
    D --> E[Control Plane Validation]
    E --> F[Upgrade Managed Node Group]
    F --> G[Create New Kubernetes Nodes]
    G --> H[Cordon Existing Node]
    H --> I[Drain Existing Node]
    I --> J[Pods Rescheduled - Protected by PDB]
    J --> K[Remove Old Worker Node]
    K --> L[Post-Upgrade Validation]
```

## 🚦 Zero-Downtime Node Upgrade

```mermaid
sequenceDiagram
    participant N1 as Node-1 (v1.35)
    participant N2 as Node-2 (v1.35)
    participant NN as New Node (v1.36)
    participant PDB as PodDisruptionBudget

    Note over N1,N2: Before Upgrade — Pod A, B on Node-1<br/>Pod C on Node-2
    NN->>NN: Create new node (v1.36)
    N1->>N1: Cordon (scheduling disabled)
    N1->>PDB: Drain triggers eviction
    PDB-->>N1: minAvailable respected
    N1->>NN: Pod A evicted & rescheduled
    NN-->>NN: Pod ready on new node
    N1->>N1: Delete old node
    Note over N1,N2: Repeat for remaining nodes
```


# Phase 1 - Creating a EKS cluster with 1.35 version

bash
```
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: eks-upgrade-lab
  region: us-east-1
  version: "1.28"

managedNodeGroups:
  - name: workers
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 2
    maxSize: 4
    volumeSize: 20
    amiFamily: AmazonLinux2
```

<img width="2934" height="340" alt="image" src="https://github.com/user-attachments/assets/3e0d21f7-7df4-424e-ba89-cef94bb2c55c" />

# Phase 2 deploy the workload

bash
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-demo
  namespace: upgrade-demo
spec:
  replicas: 3

  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1

  selector:
    matchLabels:
      app: nginx-demo

  template:
    metadata:
      labels:
        app: nginx-demo
    spec:
      containers:
      - name: nginx
        image: nginx:1.27
        ports:
        - containerPort: 80

        resources:
          requests:
            cpu: "100m"
            memory: "128Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"

        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5

        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 10
```
deploy and verify

<img width="2934" height="704" alt="image" src="https://github.com/user-attachments/assets/5c4cf176-36fe-451d-bf5f-9150d076595c" />

create a loadbalancer servicen for the deployment

bash
```
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: upgrade-demo
spec:
  selector:
    app: nginx-demo

  ports:
  - port: 80
    targetPort: 80

  type: LoadBalancer
```

deploy and verfiy 

<img width="2932" height="414" alt="image" src="https://github.com/user-attachments/assets/b036893f-aaa4-453b-8194-47c3e7a0b928" />

Checking pod placement on worker nodes later used for upgrade of cluster

<img width="2940" height="560" alt="image" src="https://github.com/user-attachments/assets/95f425f8-1742-45d7-adff-34e3e102e8ba" />

# Phase 3 Pod Disruption Budeget

A PodDisruptionBudget (PDB) protects your application from voluntary disruptions, such as:

Node drain (kubectl drain)
EKS managed node group upgrades
Cluster Autoscaler scale-down
Karpenter node consolidation
Manual node maintenance

It tells Kubernetes how many pods must remain available during these operations.

A PDB does not protect against involuntary disruptions like node crashes or hardware failures.

Our Application

We currently have:

Deployment
├── Replica 1
├── Replica 2
└── Replica 3

Without a PDB, Kubernetes could evict multiple pods during a node drain, increasing the risk of downtime.

With a PDB, Kubernetes will only evict pods if the required number of replicas stays available.


create PDB

bash
```
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: nginx-pdb
  namespace: upgrade-demo
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: nginx-demo
```
We have 3 replicas, so this configuration guarantees that at least 2 pods remain available during voluntary disruptions.

This means Kubernetes can evict only one pod at a time.

<img width="2736" height="248" alt="image" src="https://github.com/user-attachments/assets/51b4666f-b7a0-4cdd-bdf1-40aa1992f855" />

get detailed info by describe

bash
```
kubectl describe pdb nginx-pdb -n upgrade-demo
```

<img width="2836" height="612" alt="image" src="https://github.com/user-attachments/assets/579fd07c-0ba9-4b2d-8d63-739612e51d1c" />


How It Works During a Node Drain

Imagine your pods are distributed like this:

Node-1
 ├── Pod-A
 └── Pod-B

Node-2
 └── Pod-C

When you drain Node-1:

Kubernetes attempts to evict Pod-A.
Pod-A is rescheduled to another node.
Kubernetes waits until the new pod is Ready.
Only then can it evict another pod, ensuring at least 2 pods remain available.

This behavior is what helps achieve zero-downtime upgrades.

# Phase 5 – Validate EKS Add-on Compatibility

Why is this important?

An EKS cluster isn't just the Kubernetes control plane. It also includes managed add-ons such as:

Amazon VPC CNI – networking for pods
CoreDNS – DNS resolution inside the cluster
kube-proxy – Kubernetes service networking
EKS Pod Identity Agent (if installed)

These add-ons must be compatible with the target Kubernetes version. In production, teams always verify them before upgrading the control plane.

checking current cluster version

<img width="2936" height="274" alt="image" src="https://github.com/user-attachments/assets/1e7bd35e-6c7a-4736-8842-600d0e35ef59" />

<img width="2512" height="404" alt="image" src="https://github.com/user-attachments/assets/c4762132-d064-4050-9bf0-3f848993acb2" />

listing add ons on the cluster

<img width="2762" height="604" alt="image" src="https://github.com/user-attachments/assets/37b69496-a33b-42a9-9002-cfd7c8daabeb" />

now check this add on versions of the above list

<img width="2940" height="1016" alt="image" src="https://github.com/user-attachments/assets/9055d750-aa9a-4391-9525-ce93042c6c38" />

<img width="2934" height="1006" alt="image" src="https://github.com/user-attachments/assets/56afcd83-f1ed-47c3-85f0-a903bebbbd00" />

<img width="2940" height="1034" alt="image" src="https://github.com/user-attachments/assets/dc3cc8c5-2192-4dbd-8b3f-226f8f1f545c" />


check comptabile versions of add ons in k8s 1.36

bash
```
aws eks describe-addon-versions \
  --addon-name vpc-cni \
  --kubernetes-version 1.36

  aws eks describe-addon-versions \
  --addon-name coredns \
  --kubernetes-version 1.36

  aws eks describe-addon-versions \
  --addon-name kube-proxy \
  --kubernetes-version 1.36

 ```


check cluster health before upgrading it

# phase 4 Upgrading control plane ( 1.35 -> 1.36)

What Happens During a Control Plane Upgrade?

Only the EKS-managed control plane is upgraded:

✅ Kubernetes API Server
✅ etcd (managed by EKS)
✅ Controller Manager
✅ Scheduler

we need need to upgrade worker nodes manually after this

During this step:

Applications continue running.
Existing pods are not restarted.
The Kubernetes API may briefly be unavailable (typically a few seconds), but workloads continue serving traffic.


Control Plane Upgrade

bash
```
aws eks update-cluster-version \
  --name eks-upgrade-lab \
  --region us-east-1 \
  --kubernetes-version 1.36
```

<img width="2886" height="1162" alt="image" src="https://github.com/user-attachments/assets/e126a590-cb83-42b6-ab5d-d50c208a0607" />

monitor the upgrade

bash
```
while true; do
  clear
  aws eks describe-cluster \
    --name eks-upgrade-lab \
    --region us-east-1 \
    --query "cluster.status"
  sleep 30
done
```
verfiy the version

bash
```
aws eks describe-cluster \
  --name eks-upgrade-lab \
  --region us-east-1 \
  --query "cluster.version"
```
<img width="2640" height="322" alt="image" src="https://github.com/user-attachments/assets/7aeea1fc-7de8-4eef-b705-69eb772cf209" />


Still deployment is up and running

<img width="2928" height="1308" alt="image" src="https://github.com/user-attachments/assets/dc677d49-ab3c-4611-983c-baf09ed712a8" />


verify everything is working fine after control plane upgrade

<img width="2868" height="1580" alt="image" src="https://github.com/user-attachments/assets/daae1fbb-1f07-4a55-afc0-efbd30fadf2f" />




# Phase 7 – Upgrade the Managed Node Group,

Create replacement nodes on Kubernetes 1.36.
Cordon old nodes.
Drain them while respecting the PodDisruptionBudget.
Reschedule pods.
Terminate the old nodes.

list node groups

bash
```
eksctl get nodegroup \
  --cluster eks-upgrade-lab \
  --region us-east-1
```

<img width="2936" height="402" alt="image" src="https://github.com/user-attachments/assets/3f22556d-1cdd-4c75-acb5-cc428b3a8fe8" />


upgrade the node group

bash
```
eksctl upgrade nodegroup \
  --cluster eks-upgrade-lab \
  --name workers \
  --region us-east-1
```

<img width="2940" height="1210" alt="image" src="https://github.com/user-attachments/assets/d131a7df-e8cc-4755-88e5-22b970800d9e" />

check the node group version

bash
```
aws eks update-nodegroup-version \
  --cluster-name eks-upgrade-lab \
  --nodegroup-name workers \
  --region us-east-1
```
<img width="2836" height="1462" alt="image" src="https://github.com/user-attachments/assets/c4ea37ed-b120-4c63-b21e-e2dd22b629d6" />

Monitor the Upgrade

bash
```
aws eks describe-nodegroup \
  --cluster-name eks-upgrade-lab \
  --nodegroup-name workers \
  --region us-east-1 \
  --query "nodegroup.status"
```

check the nodes

<img width="2714" height="384" alt="image" src="https://github.com/user-attachments/assets/13b98c9d-9632-4d3c-a15d-5432a8d17527" />


verify everything

<img width="2940" height="1776" alt="image" src="https://github.com/user-attachments/assets/b367ef34-b0df-411d-8d2c-dd313f19e0f5" />


# Phase 8 – Post-Upgrade Validation & Rollback Runbook

verify kubernetes version

<img width="2474" height="286" alt="image" src="https://github.com/user-attachments/assets/8e4b429d-c699-42ad-8521-9e6c3960af9f" />

verfiy components

<img width="2888" height="676" alt="image" src="https://github.com/user-attachments/assets/dbb4556c-bc7e-4373-80eb-ae2744dafe36" />



<img width="2596" height="448" alt="image" src="https://github.com/user-attachments/assets/aece9933-1a0f-4d1b-83c4-60fa902f6ae7" />

check Events

bash
```
kubectl get events -A --sort-by=.lastTimestamp >> Events.txt
```

# Rollback Strategy

You cannot downgrade an EKS control plane.

Once the control plane is upgraded, AWS does not support rolling it back to an earlier Kubernetes version.

What can you do?
1. Before the upgrade
Export Kubernetes manifests:
kubectl get all -A -o yaml > cluster-backup.yaml
Backup persistent data (for example, database snapshots or volume snapshots).
Verify infrastructure code (Terraform, CloudFormation, or eksctl configs) is up to date.

#  If the upgrade causes issues

Possible actions:

Roll back your application deployment:
kubectl rollout undo deployment/nginx-demo -n upgrade-demo
Roll back Helm releases (if Helm is used):
helm rollback <release-name> <revision>
Restore configuration from Git if using GitOps.

# If the cluster becomes unusable

Recovery plan:

Create a new EKS cluster on a supported Kubernetes version.
Install required add-ons.
Restore workloads from Git or backups.
Restore persistent data.
Switch DNS or load balancer traffic to the new cluster.
Decommission the old cluster after validation.

## 🎓 Learning Outcomes


- ➤ Kubernetes version upgrade planning
- ➤ Amazon EKS control plane upgrades
- ➤ Managed node group upgrades
- ➤ PodDisruptionBudget implementation
- ➤ Node cordon and drain workflow
- ➤ Zero-downtime application upgrades
- ➤ Cluster validation techniques
- ➤ Production rollback planning
- ➤ Real-world EKS operational best practices


