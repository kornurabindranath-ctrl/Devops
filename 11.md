# Day 13 - Kubernetes Scheduling Patterns

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![AWS EKS](https://img.shields.io/badge/AWS%20EKS-FF9900?style=for-the-badge&logo=amazon-eks&logoColor=white)
![eksctl](https://img.shields.io/badge/eksctl-1B1F23?style=for-the-badge&logo=amazonaws&logoColor=white)
![Status](https://img.shields.io/badge/Status-Production%20Pattern-success?style=for-the-badge)


Kubernetes doesn't place pods randomly — but left to defaults, it doesn't place them *intelligently* either. This project implements four core scheduling strategies on Amazon EKS to control workload placement for better **availability, isolation, resiliency, and resource utilization**.

**Goal →** GPU workloads on GPU nodes. Replicas spread across nodes. Traffic spread across AZs. Infra workloads on dedicated pools. No exceptions.

---
Production-grade workload placement on EKS — using labels, node affinity, taints, tolerations, pod anti-affinity, topology spread constraints, and dedicated node pools to control where and how your pods run.

## 🏗️ Architecture

```mermaid
flowchart TB
    subgraph EKS["Amazon EKS Cluster"]
        direction LR

        subgraph AZ_A["us-east-1a"]
            GPU["🎮 GPU Node<br/>accelerator=nvidia<br/>taint: gpu=true:NoSchedule"]
        end

        subgraph AZ_B["us-east-1b"]
            MON["📊 Monitoring Node<br/>dedicated=monitoring<br/>taint: dedicated=monitoring:NoSchedule"]
        end

        subgraph AZ_C["us-east-1c"]
            WRK["⚙️ Worker Node<br/>general purpose"]
        end

        GPU --> GPUW["GPU Workloads<br/>(Node Affinity)"]
        MON --> MONW["Prometheus<br/>(Dedicated Pool)"]
        WRK --> APPW["Application Pods<br/>(Anti-Affinity)"]
    end

    GPUW & MONW & APPW --> TSC["🌐 Topology Spread Constraints<br/>Even distribution across 1a • 1b • 1c"]
```

# Phase 1 Setting up a EKS cluster

bash
```
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: scheduling-lab
  region: us-east-1

availabilityZones:
- us-east-1a
- us-east-1b
- us-east-1c

managedNodeGroups:

- name: general

  instanceType: t3.medium

  desiredCapacity: 3

  availabilityZones:
   - us-east-1a
   - us-east-1b
   - us-east-1c


   eksctl create cluster -f cluster.yaml
```
wait for 15-20 mins for cluster to come up

verify the cluster

<img width="2940" height="538" alt="image" src="https://github.com/user-attachments/assets/e56810f6-7ec0-45be-b6af-972cca29fac6" />

# Phase 2 Understanding Current Topology and added labels 

bash
```
kubectl get nodes \
-L topology.kubernetes.io/zone
```

<img width="2574" height="374" alt="image" src="https://github.com/user-attachments/assets/ce31e04f-a2cb-400d-b68b-61c487364410" />



Labal the nodes 

bash
```
kubectl label node ip-192-168-65-123.ec2.internal workload=general

 kubectl label node ip-192-168-45-14.ec2.internalworkload=general 

 kubectl label node ip-192-168-25-154.ec2.internal workload=gpu
```

verify the labels

bash
```
kubectl get nodes --show-labels
```
<img width="2940" height="1424" alt="image" src="https://github.com/user-attachments/assets/6e94d262-c32e-4132-bdb9-e3125c556a05" />

Real GPU nodes are expensive.

We'll emulate them.

bash
```
 kubectl label node ip-192-168-25-154.ec2.internal accelerator=nvidia
```
verify

<img width="2938" height="532" alt="image" src="https://github.com/user-attachments/assets/eabef536-0172-4a91-a1ca-1985f73317d2" />

# phase 3 - taint the nodes

bash
```
kubectl taint node ip-192-168-25-154.ec2.internal gpu=true:NoSchedule
```

verify 
bash
```
kubectl describe node ip-192-168-25-154.ec2.internal | grep -A3 Taints
```

<img width="2940" height="526" alt="image" src="https://github.com/user-attachments/assets/c34c1da3-9625-41e3-a977-6900df83085a" />

we hve tained a node lets see sample deployment will schedule

bash
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: normal-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: normal-app
  template:
    metadata:
      labels:
        app: normal-app
    spec:
      containers:
      - name: nginx
        image: nginx
```

deploy and verify the pods

we can observe that pods are not sceduled on ip-192-168-25-154.ec2.internal because it is tainted

<img width="2940" height="588" alt="image" src="https://github.com/user-attachments/assets/ea9b18c9-90bf-4ad2-ba2a-29e55cf17791" />


Now test to deploy gpu with tolerations

bash
```
apiVersion: apps/v1
kind: Deployment

metadata:
  name: gpu-app

spec:
  replicas: 1

  selector:
    matchLabels:
      app: gpu

  template:

    metadata:
      labels:
        app: gpu

    spec:

      tolerations:
      - key: gpu
        operator: Equal
        value: "true"
        effect: NoSchedule

      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: accelerator
                operator: In
                values:
                - nvidia

      containers:
      - name: app
        image: nginx
```

verfiy pod is scheduled on the tainted node because of matching toleration on the pod

Objective → Ensure GPU workloads land only on GPU-capable nodes.

Techniques → Node Labels · Taints · Tolerations · Node Affinity

<img width="2940" height="278" alt="image" src="https://github.com/user-attachments/assets/4282512e-a25e-442c-847c-2a5feb3d576a" />

# Phase 4 Anti affinity

Objective → Prevent replicas from landing on the same node.

Benefits → High Availability · Fault Isolation · Better Resilience



bash
```
apiVersion: apps/v1
kind: Deployment

metadata:
  name: web

spec:
  replicas: 3

  selector:
    matchLabels:
      app: web

  template:

    metadata:
      labels:
        app: web

    spec:

      affinity:

        podAntiAffinity:

          requiredDuringSchedulingIgnoredDuringExecution:

          - labelSelector:

              matchExpressions:

              - key: app

                operator: In

                values:

                - web

            topologyKey: kubernetes.io/hostname

      containers:

      - name: nginx

        image: nginx
```

only replica needs to be there for one node, one is pending because node tainted the pod don't have any toleration to scedule on that

<img width="2938" height="568" alt="image" src="https://github.com/user-attachments/assets/963bb50b-abc7-4d89-b372-c2f4c11758bb" />

Zone Spreading

Objective → Distribute workloads evenly across Availability Zones.

Benefits → Multi-AZ Resilience · Reduced Blast Radius · Better Fault Tolerance

bash
```
apiVersion: apps/v1
kind: Deployment

metadata:
  name: api

spec:
  replicas: 6

  selector:
    matchLabels:
      app: api

  template:

    metadata:
      labels:
        app: api

    spec:

      topologySpreadConstraints:

      - maxSkew: 1

        topologyKey: topology.kubernetes.io/zone

        whenUnsatisfiable: DoNotSchedule

        labelSelector:

          matchLabels:
            app: api

      containers:

      - name: nginx

        image: nginx
```

deploy and verfiy the scheduling

<img width="2764" height="202" alt="image" src="https://github.com/user-attachments/assets/f1950102-2362-48fc-8651-b415047dc51f" />



# phase 5 Dedicated node pools

Objective → Reserve nodes exclusively for infrastructure workloads.

Examples → Prometheus · Grafana · ELK / OpenSearch · Security Agents · CI/CD Runners

  Choose one node 

  bash
  ```
  kubectl label node ip-192-168-45-14.ec2.internal dedicated=monitoring
  ```
 verify 
 
<img width="2940" height="428" alt="image" src="https://github.com/user-attachments/assets/22af6008-1794-4bf4-be48-327bba679deb" />

Tainting the node

bash
```
kubectl taint node ip-192-168-45-14.ec2.internal dedicated=monitoring:NoSchedule
```

deploy the monitoring workload

bash
```
apiVersion: apps/v1
kind: Deployment

metadata:
  name: prometheus

spec:
  replicas: 1

  selector:
    matchLabels:
      app: prometheus

  template:

    metadata:
      labels:
        app: prometheus

    spec:

      tolerations:

      - key: dedicated
        operator: Equal
        value: monitoring
        effect: NoSchedule

      affinity:

        nodeAffinity:

          requiredDuringSchedulingIgnoredDuringExecution:

            nodeSelectorTerms:

            - matchExpressions:

              - key: dedicated
                operator: In
                values:
                - monitoring

      containers:

      - name: prometheus

        image: prom/prometheus
```

deploy and verify

<img width="2940" height="412" alt="image" src="https://github.com/user-attachments/assets/417a0c58-174b-4c07-b017-1e03b5a02253" />

Only the monitoring node should host the pod.


After completing this project, you'll understand:

- ➤ How the Kubernetes scheduler makes placement decisions
- ➤ How to isolate GPU workloads onto dedicated hardware
- ➤ How to implement workload segregation via taints/tolerations
- ➤ How to design highly available applications with anti-affinity
- ➤ How to distribute applications across Availability Zones
- ➤ How to create dedicated infrastructure node pools
- ➤ Production scheduling strategies used in enterprise Kubernetes clusters
