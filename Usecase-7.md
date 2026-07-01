# Day 7 - Build an Intelligent Autoscaling Lab on EKS demonstrating:

HPA (CPU)
HPA (Memory)
VPA
KEDA
SQS
IRSA
Scale-to-Zero

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


 # Phase 4 HPA Memory

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





    





