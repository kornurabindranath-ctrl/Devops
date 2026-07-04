# Day 10 - Service mesh with Istio
mTLS between services, traffic shifting, circuit breakers, fault injection testing, retry policies.

# Phase 1 Create a Cluster

Bash
```
eksctl create cluster \
--name istio-prod \
--region us-east-1 \
--nodes 3 \
--node-type t3.large
```
Verfiy

bash
```
kubectl get nodes
```

# phase 2 Install ISTIO

Download ISTIO resources 
bash
```
curl -L https://istio.io/downloadIstio | sh -

cd istio-1.30.2

export PATH=$PWD/bin:$PATH
```
Install Istio profile

bash
```
istioctl install \
--set profile=demo \
-y
```
Verify
bash
```
istioctl version

kubectl get pods -n istio-system
```
<img width="2460" height="1544" alt="image" src="https://github.com/user-attachments/assets/94af7b0f-fbf8-4089-9165-5d453e352ad1" />

# Phase 3 To enable sidecar containers we need to set labels 

bash
```
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    istio-injection: enabled
```
apply and verfiy the labels

<img width="2802" height="420" alt="image" src="https://github.com/user-attachments/assets/bc6347c9-ee80-4ae8-a464-97a340809375" />

# Phase 4 Deploying application

Backend v1 and Backend v2

bash
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-v1
  namespace: production
spec:
  replicas: 2

  selector:
    matchLabels:
      app: backend
      version: v1

  template:

    metadata:
      labels:
        app: backend
        version: v1

    spec:
      containers:

      - name: backend

        image: hashicorp/http-echo

        args:
        - "-text=v1"

        ports:
        - containerPort: 5678
```

backend v2

bash
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-v2
  namespace: production
spec:
  replicas: 2

  selector:
    matchLabels:
      app: backend
      version: v2

  template:

    metadata:
      labels:
        app: backend
        version: v2

    spec:
      containers:

      - name: backend

        image: hashicorp/http-echo

        args:
        - "-text=v2"

        ports:
        - containerPort: 5678
```

Frontend 

bash
```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: production
spec:
  replicas: 2

  selector:
    matchLabels:
      app: frontend

  template:
    metadata:
      labels:
        app: frontend

    spec:
      containers:
      - name: frontend
        image: nginx
        ports:
        - containerPort: 80
```

Deploy and verify them

<img width="2424" height="514" alt="image" src="https://github.com/user-attachments/assets/a06c7f73-9aa4-48ad-9d94-0ffbf0ccc56c" />


Services for deployments

backend service
bash
```
apiVersion: v1
kind: Service

metadata:
  name: backend
  namespace: production

spec:
  selector:
    app: backend

  ports:
  - name: http
    port: 80
    targetPort: 5678
```

frontend service

bash
```
apiVersion: v1
kind: Service

metadata:
  name: frontend
  namespace: production

spec:
  selector:
    app: frontend

  ports:
  - name: http
    port: 80
    targetPort: 80
```
deploy and verify

<img width="2544" height="228" alt="image" src="https://github.com/user-attachments/assets/d34a4e3a-e112-4448-af14-8b73ad39b75b" />


<img width="2934" height="218" alt="image" src="https://github.com/user-attachments/assets/40aec5a6-2dac-40d2-ad04-550160b3fef4" />

create a destinationRule to oute traffic

bash
```
apiVersion: networking.istio.io/v1

kind: DestinationRule

metadata:
  name: backend
  namespace: production

spec:
  host: backend

  subsets:

  - name: v1
    labels:
      version: v1

  - name: v2
    labels:
      version: v2
```
<img width="2794" height="236" alt="image" src="https://github.com/user-attachments/assets/04c37112-c33c-4d35-84d0-0dac3ad377da" />

VirtualService

bash
```
apiVersion: networking.istio.io/v1

kind: VirtualService

metadata:
  name: backend
  namespace: production

spec:

  hosts:
    - backend

  http:

  - route:

    - destination:
        host: backend
        subset: v1
      weight: 90

    - destination:
        host: backend
        subset: v2
      weight: 10
```
 <img width="2640" height="240" alt="image" src="https://github.com/user-attachments/assets/79f13e86-5637-45bf-9df2-91ed6a2a6fce" />

 inpect the routing for enovy sidecar

 bash
 ```
istioctl proxy-config routes \
backend-v1-5678647859-7vblk \
-n production
 ```

 <img width="2940" height="618" alt="image" src="https://github.com/user-attachments/assets/6d96ba53-447f-4557-850a-6c87cccfe16f" />

it confirms that:

backend → the service is known to Envoy.
backend|80|v1 → Envoy has a route to version v1.
backend|80|v2 → Envoy has a route to version v2.

Testing traffic spliting

bash
```
kubectl exec -it deploy/frontend -n production -- sh
```

run inside the container

bash 
```
for i in $(seq 1 100); do
  echo "Request $i"
  curl -s http://backend
  echo
done
```
we can observe that 90 percent requests to v1 and 10 percent to v2

<img width="1114" height="1426" alt="image" src="https://github.com/user-attachments/assets/30f2d6eb-19ee-4425-b630-7f0400529211" />


# Phase 5 Enable mTLS

create peer authentication

bash
```
apiVersion: security.istio.io/v1

kind: PeerAuthentication

metadata:
  name: default
  namespace: production

spec:

  mtls:

    mode: STRICT
```

verify for one pod

<img width="2938" height="968" alt="image" src="https://github.com/user-attachments/assets/fe92abb2-146a-462c-b2cf-bfcc13f7cb7d" />


adding Retry polices in virtual service

Frontend
   │
   ▼
Backend v1

1st request → fails (503)
Istio retries
2nd request → succeeds

Client sees success

This improves resiliency against transient failures.

bash
```
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: backend
  namespace: production

spec:
  hosts:
  - backend

  http:
  - route:
    - destination:
        host: backend
        subset: v1
      weight: 90

    - destination:
        host: backend
        subset: v2
      weight: 10

    retries:
      attempts: 3
      perTryTimeout: 2s
      retryOn: "5xx,connect-failure,refused-stream"

```

deploy and verify the configuration

<img width="2938" height="1288" alt="image" src="https://github.com/user-attachments/assets/c222c23e-0aba-42b6-8457-df93ca541645" />


# Phase 6 Circuit breaker

Without a circuit breaker:

Frontend
   │
   ▼
Backend (slow/failing)

1000 requests
1000 failures

With a circuit breaker:

Frontend
   │
   ▼
Istio Proxy
   │
   ├── Healthy → Forward request
   └── Unhealthy → Stop sending traffic

Backend

Istio can:

limit connections
limit pending requests
eject unhealthy endpoints
prevent cascading failures

Modify destinationRule config by adding traffic policy

bash
```
apiVersion: networking.istio.io/v1

kind: DestinationRule

metadata:
  name: backend
  namespace: production

spec:
  host: backend

  subsets:

  - name: v1
    labels:
      version: v1

  - name: v2
    labels:
      version: v2

  trafficPolicy:

    connectionPool:

      tcp:

        maxConnections: 1

      http:

        http1MaxPendingRequests: 1

        maxRequestsPerConnection: 1

    outlierDetection:

      consecutive5xxErrors: 1

      interval: 5s

      baseEjectionTime: 30s

      maxEjectionPercent: 100
```

deploy and verify config chnage

<img width="2748" height="1236" alt="image" src="https://github.com/user-attachments/assets/462159a1-9feb-46cb-b317-be01812289c8" />

deploy load generator image folio
bash
```
kubectl apply -n production \
-f https://raw.githubusercontent.com/istio/istio/release-1.30/samples/httpbin/sample-client/fortio-deploy.yaml
```
<img width="2882" height="560" alt="image" src="https://github.com/user-attachments/assets/3c730863-1d04-4f34-8e0d-059f5ff62939" />

load test

bash
```
kubectl exec \
-n production \
deploy/fortio-deploy \
-c fortio \
-- fortio load \
-c 50 \
-qps 0 \
-t 30s \
http://backend
```

<img width="2940" height="1398" alt="image" src="https://github.com/user-attachments/assets/c1d464ed-8a1c-4367-a31c-85f05a3802cf" />

Fortio
   │
   │ 50 concurrent requests
   ▼

Envoy Sidecar

maxConnections = 1

Only one connection allowed

Queue fills

Pending requests overflow

Envoy returns 503

Backend protected

This is the exact purpose of a circuit breaker:

prevent overload
avoid cascading failures
eject unhealthy endpoints
maintain service stability


# Phase 7 Fault injection

Fault injection allows us to simulate:

Latency spikes
Backend slowness
Service failures
Chaos engineering scenarios


Delay Injection

bash
```
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: backend
  namespace: production

spec:
  hosts:
  - backend

  http:
  - fault:
      delay:
        percentage:
          value: 100
        fixedDelay: 5s

    route:
    - destination:
        host: backend
        subset: v1
      weight: 90

    - destination:
        host: backend
        subset: v2
      weight: 10
```

deploy and verfiy fault injection

<img width="2876" height="566" alt="image" src="https://github.com/user-attachments/assets/a9101be0-389a-4a71-a66f-a57cb027542a" />

simulating 5 sec delay





