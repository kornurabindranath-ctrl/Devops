# BatchJob operator

Before stating need to setup required tools

bash
```
go version
kubectl version --client
kubebuilder version
operator-sdk version
kind version
kustomize version
```

creating a EKS cluster

bash
```
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: operator-lab
  region: ap-south-1

managedNodeGroups:
  - name: operator-workers
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 2
    maxSize: 3
    volumeSize: 20
```
bash
```
eksctl create cluster -f cluster-config.yaml

```


verify the cluster

bash
```
kubectl get nodes
```

<img width="2624" height="448" alt="image" src="https://github.com/user-attachments/assets/2ccd6dbf-8057-4736-bdaf-f26b61e2dfc6" />

Intializing the project 

bash
```
kubebuilder init \
  --domain rk.io \
  --repo github.com/kornurabindath-ctrl/Devops/Usecase-16-BatchJob-Operator
```
you can observe the directories
<img width="1990" height="1720" alt="image" src="https://github.com/user-attachments/assets/c5dcb2fb-8093-4cc5-870a-0079ad065d3c" />

This is heart of kube builder( lets you to build the operator and contains all the configuration and controller script (go.mod ))

Creating an API

bash
```
kubebuilder create api \
  --group platform \
  --version v1alpha1 \
  --kind BatchJob
```

<img width="2250" height="780" alt="image" src="https://github.com/user-attachments/assets/a4d6fe23-1ec8-488d-b757-1688c5d21158" />

# Design the Custom Resource and  Kubebuilder Markers(Think of them like annotations in Spring Boot or decorators in Python—they influence generated artifacts.)


api/v1alpha1/batchjob_types.go


Add this two jobspec and jobstatus fields
bash
```

// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=".status.phase"
// +kubebuilder:printcolumn:name="Job",type=string,JSONPath=".status.jobName"
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=".metadata.creationTimestamp"
type BatchJobSpec struct {
    // +kubebuilder:validation:MinLength=1
    Image string `json:"image"`
    Command                  []string `json:"command,omitempty"`
    // +kubebuilder:default:=3
   // +kubebuilder:validation:Minimum=0
    BackoffLimit int32 `json:"backoffLimit,omitempty"`
    // +kubebuilder:default:=300
   // +kubebuilder:validation:Minimum=0
   TTLSecondsAfterFinished int32 `json:"ttlSecondsAfterFinished,omitempty"`
}
// +kubebuilder:subresource:status
type BatchJobStatus struct {
    Phase          string      `json:"phase,omitempty"`
    JobName        string      `json:"jobName,omitempty"`
    StartTime      metav1.Time `json:"startTime,omitempty"`
    CompletionTime metav1.Time `json:"completionTime,omitempty"`
}
```
bash
```
make manifests
```

now CRD is generated under 

/config/crd/bases/platform.rk.io_batchjobs.yaml

bash
```
ravindranathkornu@Ravindranaths-MacBook-Air bases % cat platform.rk.io_batchjobs.yaml 
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  annotations:
    controller-gen.kubebuilder.io/version: v0.21.0
  name: batchjobs.platform.rk.io
spec:
  group: platform.rk.io
  names:
    kind: BatchJob
    listKind: BatchJobList
    plural: batchjobs
    singular: batchjob
  scope: Namespaced
  versions:
  - additionalPrinterColumns:
    - jsonPath: .status.phase
      name: Phase
      type: string
    - jsonPath: .status.jobName
      name: Job
      type: string
    - jsonPath: .metadata.creationTimestamp
      name: Age
      type: date
    name: v1alpha1
    schema:
      openAPIV3Schema:
        description: BatchJob is the Schema for the batchjobs API
        properties:
          apiVersion:
            description: |-
              APIVersion defines the versioned schema of this representation of an object.
              Servers should convert recognized schemas to the latest internal value, and
              may reject unrecognized values.
              More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#resources
            type: string
          kind:
            description: |-
              Kind is a string value representing the REST resource this object represents.
              Servers may infer this from the endpoint the client submits requests to.
              Cannot be updated.
              In CamelCase.
              More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#types-kinds
            type: string
          metadata:
            type: object
          spec:
            description: BatchJobSpec defines the desired state of BatchJob
            properties:
              backoffLimit:
                default: 3
                format: int32
                minimum: 0
                type: integer
              command:
                items:
                  type: string
                minItems: 1
                type: array
              image:
                minLength: 1
                type: string
              ttlSecondsAfterFinished:
                default: 300
                format: int32
                minimum: 0
                type: integer
            required:
            - command
            - image
            type: object
          status:
            description: BatchJobStatus defines the observed state of BatchJob
            properties:
              completionTime:
                format: date-time
                type: string
              jobName:
                type: string
              phase:
                enum:
                - Pending
                - Running
                - Succeeded
                - Failed
                type: string
              startTime:
                format: date-time
                type: string
            type: object
        type: object
    served: true
    storage: true
    subresources:
      status: {}
```

Now install the CRD

bash
```
make install
```

<img width="2940" height="882" alt="image" src="https://github.com/user-attachments/assets/3c1f9fd9-b7d6-4ee3-998a-84a8fdcdd9ef" />

verfiy the CRD

bash
```
kubectl get crd | grep batchjob
```

<img width="2170" height="150" alt="image" src="https://github.com/user-attachments/assets/fb7ebeb0-0a6f-49fb-851d-e63d59ea5155" />

make generate → Generates Go code (DeepCopy methods).
make manifests → Generates Kubernetes YAML (CRDs, RBAC, etc.).
make install → Applies the CRD to the cluster.
make run → Runs the operator locally against the cluster.
make deploy → Deploys the operator into the cluster.

bash
```
kubectl api-resources | grep batch
```
<img width="2360" height="214" alt="image" src="https://github.com/user-attachments/assets/9d6a4940-e67b-4e63-bbaa-6adf477e8301" />

To get every field explination
bash
```
kubectl explain batchjobs
```
<img width="2640" height="1204" alt="image" src="https://github.com/user-attachments/assets/4002532e-73bf-4562-8dea-4dc6fdc274fd" />

To deep down

bash
```
kubectl explain batchjobs.status
```
<img width="2670" height="992" alt="image" src="https://github.com/user-attachments/assets/c9a7f1d4-7804-411c-ba3f-15c89f9bde4b" />


This is where kubebuilder markers will help

# Heart of operator 

internal/controller/batchjob_controller.go

bash
```
func (r *BatchJobReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
        _ = logf.FromContext(ctx)

        // TODO(user): your logic here

        return ctrl.Result{}, nil
}
```
This function defines how operaror would work

Now we are adding changes in this above function

bash
```
var batchJob platformv1alpha1.BatchJob

if err := r.Get(ctx, req.NamespacedName, &batchJob); err != nil {
    return ctrl.Result{}, client.IgnoreNotFound(err)
}

log := logf.FromContext(ctx)
log.Info("Reconciling BatchJob", "name", batchJob.Name)

return ctrl.Result{}, nil
```

Run the controller locally

bash
```
make run
```
<img width="2940" height="648" alt="image" src="https://github.com/user-attachments/assets/b46a6c2e-186e-4e35-92e4-b8d583128230" />


bash
```
batchjob.yaml

apiVersion: platform.rk.io/v1alpha1
kind: BatchJob
metadata:
  name: hello-job
spec:
  image: busybox
  command:
    - sh
    - -c
    - echo "Hello from Operator" && sleep 10
```
As soon as I deployed 

kubectl apply
        │
        ▼
API Server
        │
        ▼
Controller Runtime
        │
        ▼
Reconcile()

<img width="2932" height="284" alt="image" src="https://github.com/user-attachments/assets/e3a91c2f-92c6-4760-8a72-4c15f9e1c682" />

bash
```
kubectl apply
        │
        ▼
API Server
        │
        ▼
etcd
        │
        ▼
BatchJob object stored
        │
        ▼
Controller Runtime receives Watch Event
        │
        ▼
Adds item to Work Queue
        │
        ▼
Worker picks it up
        │
        ▼
Reconcile()
        │
        ▼
r.Get(...)
        │
        ▼
Log printed
```


It should ask:

"Does a Kubernetes Job already exist for this BatchJob?"

Not:

"Create a Job."

Why?

Because Reconcile() can run many times.

Imagine this sequence:

Create BatchJob
        │
        ▼
Reconcile()

Then someone edits a label.

Reconcile()

Then the status changes.

Reconcile()

Then the controller restarts.

Reconcile()

If we blindly create a Job every time...

Job-1

Job-2

Job-3

Job-4

That's a bug.


Updated the functionality

bash
```

func (r *BatchJobReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	var batchJob platformv1alpha1.BatchJob

	if err := r.Get(ctx, req.NamespacedName, &batchJob); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	log := logf.FromContext(ctx)
	log.Info("Reconciling BatchJob", "name", batchJob.Name)

        var job batchv1.Job
        err := r.Get(
	ctx,
	client.ObjectKey{
		Namespace: batchJob.Namespace,
		Name:      batchJob.Name,
	},
	&job,
)
if err != nil {
	log.Info("Job does not exist")
	return ctrl.Result{}, nil
}

log.Info("Job already exists")

	return ctrl.Result{}, nil
}
```

then  Run the controller



Reconcile()
    │
    ▼
Read BatchJob ✅
    │
    ▼
Read Kubernetes Job ✅
    │
    ▼
Job Found?
    │
    └── No
          │
          ▼
Print "Job does not exist" ✅

Instead of Instead of:

log.Info("Job does not exist")

we will create a kubernetes Job

need to write the code in controller.go

bash
```
func (r *BatchJobReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	var batchJob platformv1alpha1.BatchJob

	if err := r.Get(ctx, req.NamespacedName, &batchJob); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	log := logf.FromContext(ctx)
	log.Info("Reconciling BatchJob", "name", batchJob.Name)

	var job batchv1.Job
	err := r.Get(
		ctx,
		client.ObjectKey{
			Namespace: batchJob.Namespace,
			Name:      batchJob.Name,
		},
		&job,
	)
      jobToCreate := &batchv1.Job{
	ObjectMeta: metav1.ObjectMeta{
		Name:      batchJob.Name,
		Namespace: batchJob.Namespace,
	},
	Spec: batchv1.JobSpec{
		Template: corev1.PodTemplateSpec{
			Spec: corev1.PodSpec{
				RestartPolicy: corev1.RestartPolicyNever,
				Containers: []corev1.Container{
					{
						Name:    "worker",
						Image:   batchJob.Spec.Image,
						Command: batchJob.Spec.Command,
					},
				},
			},
		},
	},
}
   _ = jobToCreate
	
      if err != nil {

	log.Info("Creating Kubernetes Job")

	if err := r.Create(ctx, jobToCreate); err != nil {
		return ctrl.Result{}, err
	}

	log.Info("Job Created Successfully")

	return ctrl.Result{}, nil
}

	log.Info("Job already exists")

	return ctrl.Result{}, nil
}
```
bash
```
make run

kubectl delete batchjob hello-job

kubectl apply -f Batchjobs.yaml

kubectl get jobs

kubectl get pods

```
<img width="2838" height="488" alt="image" src="https://github.com/user-attachments/assets/b6144bd4-a827-4a87-9623-a0639c8c0332" />

if job is not there kubernetes is automatically creating once we are creating the batchjob which is custom object . operator is working is fine.


# Owner References


delete the batch job is creating

bash
```
kubectl delete batchjob hello-job
```
<img width="2432" height="520" alt="image" src="https://github.com/user-attachments/assets/bf026f30-980b-459c-aa7f-225ead52b239" />

It should also ensure the Job is deleted when its parent disappears.

bash
```
Importing
"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"


if err := controllerutil.SetControllerReference(&batchJob, jobToCreate, r.Scheme); err != nil {
	return ctrl.Result{}, err
}
```


<img width="2928" height="1146" alt="image" src="https://github.com/user-attachments/assets/1f77793d-a0a8-4c52-8fda-63b812d0018f" />

once i have deleted the batch job

<img width="2654" height="350" alt="image" src="https://github.com/user-attachments/assets/f299426e-ea87-4edf-8e45-c9fcc32a525b" />

job and pod also removed 

# Status management

But where can a user see whether the Job actually succeeded?

make chnages

bash
```
batchJob.Status.Phase = "Pending"
batchJob.Status.JobName = jobToCreate.Name

if err := r.Status().Update(ctx, &batchJob); err != nil {
	return ctrl.Result{}, err
}
```

run make run and delete old batch job and job and recreate them and inpect them you can check status


<img width="2940" height="1176" alt="image" src="https://github.com/user-attachments/assets/b629cbf1-1fe1-4509-afbe-b24f66a37eff" />

Because our operator only updates the status once, immediately after creating the Job.

It never checks again what happened to that Job.

# Watch the child Job
bash
```
        Watch
          │
          ▼
     Reconcile()
          │
          ▼
 Update Cluster
          │
          ▼
      Wait...
          │
          ▼
Something changes
          │
          ▼
     Reconcile() Again
          │
          ▼
Update Status Again
```


bash
```
BatchJob Created
        │
        ▼
Create Job
        │
        ▼
Job starts Running
        │
        ▼
Controller is notified
        │
        ▼
Reconcile()
        │
        ▼
Update Status = Running

--------------------------

Job Completes
        │
        ▼
Controller is notified
        │
        ▼
Reconcile()
        │
        ▼
Update Status = Succeeded
```
We never poll Kubernetes.

Kubernetes tells us when something changes.

This is called event-driven reconciliation.

SetControllerReference() → tells Kubernetes who owns the Job.
Owns() → tells controller-runtime to watch owned Jobs.

bash
```
func (r *BatchJobReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&platformv1alpha1.BatchJob{}).
		Owns(&batchv1.Job{}).
		Named("batchjob").
		Complete(r)
}

```

run and delete and recreate the objects

<img width="2940" height="840" alt="image" src="https://github.com/user-attachments/assets/614cf3f4-a3c5-4d8e-8a8e-1d36bee7d665" />

i can reconcilation is happening

checking status

<img width="2832" height="834" alt="image" src="https://github.com/user-attachments/assets/723c631c-b115-4532-a464-d3183afb3827" />

