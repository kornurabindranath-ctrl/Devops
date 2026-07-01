# Day 7 - Kubernetes Intelligent Autoscaling Lab

**HPA • VPA • KEDA with Amazon SQS on AWS EKS**


```mermaid
flowchart TB
    subgraph AWS["AWS Cloud"]
        subgraph EKS["Amazon EKS Cluster"]
            HPA[HPA]
            VPA[VPA]
            KEDA[KEDA]

            HPA --> S1[Scale Pods]
            VPA --> S2[Right-size Pods]
            KEDA --> S3[Scale on Events]
        end
    end
```

# project structure 

<img width="2520" height="904" alt="image" src="https://github.com/user-attachments/assets/fd0e2a6e-8bd5-4158-8d88-c8bf8795cdb5" />


## Phase 0 setup kubectl,eksctl,awscli,aws configure

## Phase 1 - Creating a EKS Cluster

bash
```
  eksctl create cluster \
--name autoscaling-lab \
--region us-east-1 \
--nodes 2 \
--node-type t3.medium
```

wait for 20 mins to  EKS create a cluster

<img width="2936" height="1290" alt="image" src="https://github.com/user-attachments/assets/58d42d3e-25cd-422e-bacc-425e35e3ec2d" />

Now EKS cluster is ready


# Phase 2 — Metrics Server

  bash
  ```
  kubectl apply -f \
https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   ```

  kubectl get pods -n kube-system
  
   <img width="2580" height="578" alt="image" src="https://github.com/user-attachments/assets/c5365c53-f453-42d7-b164-1ce560849da5" />

  <img width="2928" height="272" alt="image" src="https://github.com/user-attachments/assets/e6a49ed5-45b8-40a3-bf6f-857cb72f8fce" />

  If find similair issue then edit metric server
  
  bash
  ```
  kubectl edit deployment metrics-server -n kube-system
  ```
  add these lines
  bash 
  ```
   - --kubelet-insecure-tls
   - --kubelet-preferred-address-types=InternalIP
   ```
   Restart metric server
   
  bash
  ```
   kubectl rollout restart deployment metrics-server -n kube-system
   ```
   Check endpoints are there are not
   
   <img width="2936" height="298" alt="image" src="https://github.com/user-attachments/assets/cfca4dde-3b22-4e44-976d-6d9d2aab7a5a" />

   
   kubectl create namespace autoscaling

  kubectl get ns

# Phase 3  - HPA CPU

# HPA — CPU Autoscaling

Horizontal Pod Autoscaler adjusts the number of pod replicas according to CPU utilization.

### Scaling Logic

```mermaid
flowchart TD
    A[Incoming Requests] --> B[CPU Utilization]
    B --> C[HPA Controller]
    C --> D[Increase Replicas]
```


create deployment

bash
```
apiVersion: apps/v1
kind: Deployment

metadata:
  name: hpa-demo
  namespace: autoscaling

spec:
  replicas: 1

  selector:
    matchLabels:
      app: hpa-demo

  template:

    metadata:
      labels:
        app: hpa-demo

    spec:

      containers:

      - name: php-apache

        image: registry.k8s.io/hpa-example

        ports:

        - containerPort: 80

        resources:

          requests:
            cpu: 200m

          limits:
            cpu: 500m
```

  create service

  bash
  ```
apiVersion: v1
kind: Service

metadata:
  name: hpa-demo
  namespace: autoscaling

spec:

  selector:
    app: hpa-demo

  ports:

  - port: 80

    targetPort: 80
  ```

create HPA
  bash
  ```
  apiVersion: autoscaling/v2

kind: HorizontalPodAutoscaler

metadata:
  name: hpa-demo
  namespace: autoscaling

spec:

  scaleTargetRef:

    apiVersion: apps/v1

    kind: Deployment

    name: hpa-demo

  minReplicas: 1

  maxReplicas: 10

  metrics:

  - type: Resource

    resource:

      name: cpu

      target:

        type: Utilization

        averageUtilization: 50
  ```
Deploy them
  <img width="2552" height="438" alt="image" src="https://github.com/user-attachments/assets/fd47c970-1fc7-42ef-b063-d17dfa51d7cb" />

 Verify then
 <img width="2650" height="536" alt="image" src="https://github.com/user-attachments/assets/f01d52e1-8c46-4bd5-bf4b-e99082aa6754" />

 seems everthings works fine then Start load generator

 bash
 ```
 kubectl run load-generator \
-n autoscaling \
--rm -it \
--image=busybox \
-- /bin/sh
```

enter this command inside container which will increase cpu


<img width="2940" height="1322" alt="image" src="https://github.com/user-attachments/assets/09e6f761-37e6-458e-82d0-cf0616424975" />

Autoscaling based on the CPU load

<img width="2296" height="440" alt="image" src="https://github.com/user-attachments/assets/40105100-ebbe-4a97-a459-051053f85081" />

check no of pods coming up

<img width="2236" height="562" alt="image" src="https://github.com/user-attachments/assets/3af7f057-9401-435b-8847-cef9ea122308" />

Now teriminating the container with load Hpa will scale down after cooling period of 300 seconds(5 minutes).

 <img width="2610" height="1166" alt="image" src="https://github.com/user-attachments/assets/36052505-4611-4054-9acc-86c974142c0f" />


 
### Observed Behaviour

```mermaid
flowchart LR
    A["CPU Spike"] --> B["1 Pod"] --> C["4 Pods"] --> D["7 Pods"] --> E["10 Pods"] --> F["Traffic Stops"] --> G["Stabilization Window"] --> H["Scale Down"] --> I["1 Pod"]
```


 # Phase 4 HPA Memory

 ## HPA — Memory Autoscaling

Memory-based HPA adjusts replicas according to memory consumption.

### Scaling Logic

```mermaid
flowchart TD
    A[Memory Pressure] --> B[Memory Metrics]
    B --> C[HPA Controller]
    C --> D[Additional Pods]
```

  Create a  deployment.yaml

  bash
  ```
  apiVersion: apps/v1
kind: Deployment

metadata:
  name: memory-demo
  namespace: autoscaling

spec:
  replicas: 1

  selector:
    matchLabels:
      app: memory-demo

  template:

    metadata:
      labels:
        app: memory-demo

    spec:

      containers:

      - name: memory-demo

        image: polinux/stress

        command:
        - stress

        args:
        - "--vm"
        - "1"
        - "--vm-bytes"
        - "150M"
        - "--vm-hang"
        - "1"

        resources:

          requests:
            memory: 100Mi
            cpu: 100m

          limits:
            memory: 300Mi
            cpu: 500m
  ```

create Hpa for memory

bash
```
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler

metadata:
  name: memory-demo
  namespace: autoscaling

spec:

  scaleTargetRef:

    apiVersion: apps/v1

    kind: Deployment

    name: memory-demo

  minReplicas: 1

  maxReplicas: 10

  metrics:

  - type: Resource

    resource:

      name: memory

      target:

        type: Utilization

        averageUtilization: 70
```

Deploy them

bash 
```
kubectl apply -f deployment.yaml

kubectl apply -f hpa-memory.yaml
```
Verify them

<img width="2524" height="460" alt="image" src="https://github.com/user-attachments/assets/5d454dab-f5de-4eb1-9b76-ed3e4dee6cc7" />

Now scaling automatically triggers because deployment containers already have memory intensive task

<img width="2768" height="400" alt="image" src="https://github.com/user-attachments/assets/8692f06f-5553-4d13-9830-490611080b38" />

<img width="2138" height="294" alt="image" src="https://github.com/user-attachments/assets/7164fbf5-1ca7-49c9-b7bc-ed4436e0cd74" />

<img width="2244" height="684" alt="image" src="https://github.com/user-attachments/assets/f6cbd107-8d69-4cfc-aee0-6d605029317c" />

### Observed Behaviour

```mermaid
flowchart LR
    A["High Memory Usage"] --> B["1 Pod"] --> C["2 Pods"] --> D["4 Pods"] --> E["8 Pods"] --> F["10 Pods"]
```



# Phase  5 VPA

## Vertical Pod Autoscaler (VPA)

VPA dynamically recommends and adjusts resource requests based on observed workload consumption.

> Unlike HPA, VPA does **not** increase pod count — it optimizes resource allocation per pod.

### VPA Flow

```mermaid
flowchart TD
    A[Application Metrics] --> B[VPA Recommender]
    B --> C[Resource Recommendations]
    C --> D[VPA Updater]
    D --> E[Pod Recreation]
    E --> F["New CPU / Memory Requests"]
```


Clone autoscaler repo

bash
```
git clone https://github.com/kubernetes/autoscaler.git
```
bash
```
Move to cd autoscaler/vertical-pod-autoscaler
```

Install VPA
bash
```
./hack/vpa-up.sh
```

<img width="2572" height="970" alt="image" src="https://github.com/user-attachments/assets/e6e53084-610f-47a2-b1f0-1f523ba4d70f" />

Verify VPA setup

<img width="2940" height="322" alt="image" src="https://github.com/user-attachments/assets/92cc69db-5181-4886-bd21-4f24cfadc369" />

create a deployment
bash
```
apiVersion: apps/v1
kind: Deployment

metadata:
  name: vpa-demo
  namespace: autoscaling

spec:
  replicas: 1

  selector:
    matchLabels:
      app: vpa-demo

  template:

    metadata:
      labels:
        app: vpa-demo

    spec:

      containers:

      - name: stress

        image: polinux/stress

        command:

        - stress

        args:

        - "--vm"

        - "1"

        - "--vm-bytes"

        - "200M"

        - "--vm-hang"

        - "1"

        resources:

          requests:

            cpu: 100m

            memory: 100Mi

          limits:

            cpu: 500m

            memory: 500Mi
```

create VPA

bash
```
apiVersion: autoscaling.k8s.io/v1

kind: VerticalPodAutoscaler

metadata:
  name: vpa-demo

  namespace: autoscaling

spec:

  targetRef:

    apiVersion: apps/v1

    kind: Deployment

    name: vpa-demo

  updatePolicy:

    updateMode: Auto
```

deploy them

bash 
```
kubectl apply -f deployment.yaml

kubectl apply -f vpa.yaml
```
then verify VPA

<img width="2474" height="190" alt="image" src="https://github.com/user-attachments/assets/f5782884-2935-45f3-b583-d7a4d38f8366" />

VPA recommendations

<img width="1796" height="1390" alt="image" src="https://github.com/user-attachments/assets/ef2e5bad-d8b0-4b39-adda-074068bd850e" />

check current one replica and their resource requests will adjusted by VPA


# Phase 6 KEDA Installation

### KEDA Architecture

```mermaid
flowchart TD
    A[Amazon SQS] --> B[Queue Length]
    B --> C[KEDA Operator]
    C --> D[ScaledObject]
    D --> E[External Metrics]
    E --> F[Horizontal Pod Autoscaler]
    F --> G[Worker Deployment]
```

  Adding Helm repo and update

  bash
  ```
  helm repo add kedacore \
https://kedacore.github.io/charts

helm repo update
  ```

  Install KEDA using Helm
  bash
  ```
  helm install keda kedacore/keda \
--namespace keda \
--create-namespace
  ```

  <img width="2926" height="1602" alt="image" src="https://github.com/user-attachments/assets/e1dea0a9-78f1-49fd-a5cf-4d5acf1b95ae" />


  Verify installation

  bash
  ```
  kubectl get pods -n keda
  ```

 <img width="2430" height="330" alt="image" src="https://github.com/user-attachments/assets/ce1e1acf-80c6-4d55-b52f-5adccd4f4d98" />

 verify CRDS and operators

 <img width="2684" height="428" alt="image" src="https://github.com/user-attachments/assets/e8d5123b-273e-431f-bf33-94aaa85b9617" />

 <img width="2652" height="350" alt="image" src="https://github.com/user-attachments/assets/35b73bfb-0e9e-4747-8fef-3e7e0c05110b" />

external metrics

bash
```
kubectl get apiservice | grep external.metrics
```

<img width="2752" height="210" alt="image" src="https://github.com/user-attachments/assets/07df9099-184c-49ad-979c-737b3b815464" />


# KEDA enables event-driven autoscaling.

Unlike HPA, KEDA supports:

SQS

Kafka

RabbitMQ

Redis

Prometheus

Azure Service Bus

AWS CloudWatch

Custom external metrics

KEDA also supports scale-to-zero.


creating a queue 

bash
```
aws sqs create-queue \
--queue-name autoscaling
```

<img width="2518" height="336" alt="image" src="https://github.com/user-attachments/assets/af1fb39a-e08f-4576-8d29-c28c4e34893a" />

get Queue Url and Queue arn

bash
```
aws sqs get-queue-url \
--queue-name autoscaling
```

verify 

<img width="2378" height="384" alt="image" src="https://github.com/user-attachments/assets/3fcca2ce-a987-4e3a-97de-5d4e76da2738" />

## Scale-to-Zero

One of the most important capabilities demonstrated in this project is **scale-to-zero**.

Traditional HPA maintains at least one running pod. KEDA allows workloads to completely stop when no work is available.

### Behaviour

```mermaid
flowchart LR
    A["Queue Empty"] --> B["0 Pods"] --> C["Messages Arrive"] --> D["1 Pod"] --> E["2 Pods"] --> F["5 Pods"] --> G["10 Pods"] --> H["Messages Processed"] --> I["Cooldown Period"] --> J["0 Pods"]
```


# Phase 7 IRSA


Associate OICD provider

bash 
```
eksctl utils associate-iam-oidc-provider \
--cluster autoscaling-lab \
--approve
```
<img width="2722" height="370" alt="image" src="https://github.com/user-attachments/assets/a9d5fc42-8712-46e5-bb7e-ce4be73a034d" />


Verify OIDC

bash
```
aws eks describe-cluster \
--name autoscaling-lab \
--query cluster.identity.oidc.issuer
```

<img width="2434" height="326" alt="image" src="https://github.com/user-attachments/assets/81e0405b-77ba-46a2-8daa-b17e9e9b8a6c" />

create a JSOn policy to get permission for EKS to access SQS

bash
```
{
 "Version":"2012-10-17",

 "Statement":[

 {

 "Effect":"Allow",

 "Action":[

 "sqs:GetQueueAttributes",

 "sqs:GetQueueUrl",

 "sqs:ReceiveMessage"

 ],

 "Resource":"*"

 }

 ]

}
```

create a IAM POLICY 

bash
```
aws iam create-policy \
--policy-name KEDA-SQS \
--policy-document file://policy.json
```
<img width="2670" height="912" alt="image" src="https://github.com/user-attachments/assets/7dfcd9c1-6f46-4893-8d75-8fde1ed5d5a8" />

list polices

<img width="2292" height="464" alt="image" src="https://github.com/user-attachments/assets/f8f957a1-b4c2-4bce-8313-d86575ca192e" />

Create IRSA(IAM service Account)

bash
```
eksctl create iamserviceaccount \
  --cluster autoscaling-lab \
  --namespace keda \
  --name keda-operator \
  --attach-policy-arn arn:aws:iam::497508796460:policy/KEDA-SQS \
  --override-existing-serviceaccounts \
  --approve
```
verify  role created

<img width="2912" height="1264" alt="image" src="https://github.com/user-attachments/assets/f20b6ef8-fb2a-499c-828b-80cec3bb62ab" />

Restart KEDA and check rollout status

bash
```
kubectl rollout restart deployment keda-operator -n keda

kubectl rollout status deployment keda-operator -n keda
```

Verify IRSA

<img width="2706" height="1096" alt="image" src="https://github.com/user-attachments/assets/588608bb-441b-48d1-bbbb-887e88cf5df5" />


# Phase 8 Worker node and KEDA scaled object

create worker deployment

bash
```
apiVersion: apps/v1
kind: Deployment

metadata:
  name: worker
  namespace: autoscaling

spec:
  replicas: 0

  selector:
    matchLabels:
      app: worker

  template:

    metadata:
      labels:
        app: worker

    spec:

      containers:

      - name: worker

        image: busybox

        command:
        - sh
        - -c

        args:
        - |
          while true
          do
            echo "processing"
            sleep 30
          done
```

deploy and verify

<img width="2446" height="462" alt="image" src="https://github.com/user-attachments/assets/744048dc-c64e-4c06-aa4f-4eccfafd915e" />

create triggerauth and 

  bash
  ```
  apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication

metadata:
  name: aws-trigger-auth
  namespace: autoscaling

spec:
  podIdentity:
    provider: aws
  ```

  create scaledobject

  bash
  ```
  apiVersion: keda.sh/v1alpha1
kind: ScaledObject

metadata:
  name: sqs-scaler
  namespace: autoscaling

spec:

  scaleTargetRef:
    name: worker

  minReplicaCount: 0

  maxReplicaCount: 10

  pollingInterval: 15

  cooldownPeriod: 30

  triggers:

  - type: aws-sqs-queue

    authenticationRef:
      name: aws-trigger-auth

    metadata:

      queueURL: https://sqs.us-east-1.amazonaws.com/497508796460/autoscaling

      queueLength: "5"

      awsRegion: us-east-1
  ```

  deploy them and verify

  bash
  ```
  kubectl apply -f triggerauth.yaml

 kubectl apply -f scaledobject.yaml
  ```

  <img width="2938" height="414" alt="image" src="https://github.com/user-attachments/assets/22357562-0d3c-43a7-91d2-a89711dc6510" />


  # Phase  9 - Demonstrate Scale-to-Zero

  Current state of  worker

  bash
  ```
  kubectl get deploy worker -n autoscaling

  kubectl get hpa -n autoscaling
  ```

  <img width="2852" height="500" alt="image" src="https://github.com/user-attachments/assets/d02dfea9-c373-415d-bcec-031743e5654f" />

adding 50 messages to queue

bash
```
for i in {1..50}
do
aws sqs send-message \
--queue-url $QUEUE_URL \
--message-body "job-$i" >/dev/null
done
```

verify the scaling

Worker node  replicas are laucnged based on no of messages sent to queue

<img width="2674" height="1096" alt="image" src="https://github.com/user-attachments/assets/8307e956-9dbe-4ab2-9038-25e4a0165dd7" />

scaledobject

<img width="2940" height="1146" alt="image" src="https://github.com/user-attachments/assets/0b9e2c51-6392-452d-8b5b-bfad69103962" />

HPA scaling

<img width="2692" height="682" alt="image" src="https://github.com/user-attachments/assets/b4cf7693-690c-420c-a425-0703bb4bea39" />


# phase 10  Compare

## HPA vs VPA vs KEDA

| Capability                | HPA | VPA | KEDA |
| -------------------------- | :-: | :-: | :--: |
| CPU Metrics                | ✅  | ❌  | ✅   |
| Memory Metrics              | ✅  | ❌  | ✅   |
| Custom Metrics              | ✅  | ❌  | ✅   |
| External Metrics            | ✅  | ❌  | ✅   |
| SQS Queue Depth              | ❌  | ❌  | ✅   |
| Scale to Zero                | ❌  | ❌  | ✅   |
| Change Replica Count          | ✅  | ❌  | ✅   |
| Change Resource Requests       | ❌  | ✅  | ❌   |
| Event Driven                    | ❌  | ❌  | ✅   |
| Queue Based Scaling               | ❌  | ❌  | ✅   |


## When to Use What

### HPA
Best suited for:
- Stateless applications
- Web servers
- REST APIs
- Microservices
- CPU-intensive workloads

### VPA
Best suited for:
- Stateful applications
- Databases
- JVM applications
- Memory-intensive services
- Right-sizing workloads

### KEDA
Best suited for:
- Message consumers
- Background workers
- Queue processors
- Streaming systems
- Batch jobs
- Cost optimization
- Scale-to-zero workloads


# Key Learnings

**HPA**
- Efficient for CPU and memory driven scaling
- Supports resource and custom metrics
- Includes stabilization windows to prevent oscillations

**VPA**
- Provides workload right-sizing
- Reduces overprovisioning
- Optimizes cluster utilization

**KEDA**
- Enables event-driven autoscaling
- Supports external systems
- Allows workloads to scale to zero
- Reduces infrastructure costs

**IRSA**
- Eliminates static AWS credentials
- Implements least privilege access
- Improves security and operational simplicity

---

## Conclusion

This project demonstrates a complete autoscaling ecosystem on Amazon EKS, showcasing:

- Horizontal scaling
- Vertical scaling
- Event-driven scaling
- Queue-based workloads
- Secure AWS integration
- Scale-to-zero capabilities

Together, **HPA**, **VPA**, and **KEDA** provide a comprehensive autoscaling strategy for modern Kubernetes platforms.





  





















 


 



  





    





