/*
Copyright 2026.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package controller

import (
	"context"
	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	logf "sigs.k8s.io/controller-runtime/pkg/log"

	platformv1alpha1 "github.com/kornurabindath-ctrl/Devops/Usecase-16-BatchJob-Operator/api/v1alpha1"
)

// BatchJobReconciler reconciles a BatchJob object
type BatchJobReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=platform.rk.io,resources=batchjobs,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=platform.rk.io,resources=batchjobs/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=platform.rk.io,resources=batchjobs/finalizers,verbs=update

// Reconcile is part of the main kubernetes reconciliation loop which aims to
// move the current state of the cluster closer to the desired state.
// TODO(user): Modify the Reconcile function to compare the state specified by
// the BatchJob object against the actual cluster state, and then
// perform operations to make the cluster state reflect the state specified by
// the user.
//
// For more details, check Reconcile and its Result here:
// - https://pkg.go.dev/sigs.k8s.io/controller-runtime@v0.24.1/pkg/reconcile
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

	if err := controllerutil.SetControllerReference(&batchJob, jobToCreate, r.Scheme); err != nil {
		return ctrl.Result{}, err
	}

	if err != nil {

		log.Info("Creating Kubernetes Job")

		if err := r.Create(ctx, jobToCreate); err != nil {
			return ctrl.Result{}, err
		}

		log.Info("Job Created Successfully")

		batchJob.Status.Phase = "Pending"
		batchJob.Status.JobName = jobToCreate.Name
		if err := r.Status().Update(ctx, &batchJob); err != nil {
			return ctrl.Result{}, err
		}

		return ctrl.Result{}, nil
	}

	log.Info("Job already exists")

	return ctrl.Result{}, nil
}

// SetupWithManager sets up the controller with the Manager.

func (r *BatchJobReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&platformv1alpha1.BatchJob{}).
		Owns(&batchv1.Job{}).
		Named("batchjob").
		Complete(r)
}
