package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

// BatchJobSpec defines the desired state of BatchJob
type BatchJobSpec struct {
	// +kubebuilder:validation:MinLength=1
	Image string `json:"image"`

	// +kubebuilder:validation:MinItems=1
	Command []string `json:"command"`

	// +kubebuilder:default:=3
	// +kubebuilder:validation:Minimum=0
	BackoffLimit int32 `json:"backoffLimit,omitempty"`

	// +kubebuilder:default:=300
	// +kubebuilder:validation:Minimum=0
	TTLSecondsAfterFinished int32 `json:"ttlSecondsAfterFinished,omitempty"`
}

// BatchJobStatus defines the observed state of BatchJob
type BatchJobStatus struct {
	// +kubebuilder:validation:Enum=Pending;Running;Succeeded;Failed
	Phase string `json:"phase,omitempty"`

	JobName string `json:"jobName,omitempty"`

	StartTime *metav1.Time `json:"startTime,omitempty"`

	CompletionTime *metav1.Time `json:"completionTime,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=".status.phase"
// +kubebuilder:printcolumn:name="Job",type=string,JSONPath=".status.jobName"
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=".metadata.creationTimestamp"

// BatchJob is the Schema for the batchjobs API
type BatchJob struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   BatchJobSpec   `json:"spec,omitempty"`
	Status BatchJobStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// BatchJobList contains a list of BatchJob
type BatchJobList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []BatchJob `json:"items"`
}

func init() {
	SchemeBuilder.Register(func(s *runtime.Scheme) error {
		s.AddKnownTypes(SchemeGroupVersion, &BatchJob{}, &BatchJobList{})
		return nil
	})
}
