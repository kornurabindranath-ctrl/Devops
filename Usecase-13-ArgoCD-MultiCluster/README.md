# 🚀 ArgoCD Multi-Cluster GitOps on AWS EKS

> Building a production-grade GitOps platform using ArgoCD, Terraform, AWS EKS, and Kubernetes.

![Terraform](https://img.shields.io/badge/Terraform-IaC-844FBA?style=flat-square&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?style=flat-square&logo=amazonaws&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat-square&logo=kubernetes&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-GitOps-EF7B4D?style=flat-square&logo=argo&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-0F1689?style=flat-square&logo=helm&logoColor=white)
![Progress](https://img.shields.io/badge/Progress-80%25-yellow?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)

## Architecture

### Infrastructure Layer

```mermaid
flowchart TD
    AWS["AWS Cloud"] --> VPC["VPC (10.0.0.0/16)"]
    VPC --> PubSubnets["Public Subnets"]
    VPC --> PrivSubnets["Private Subnets"]
    PubSubnets --> EKS["EKS Cluster"]
    PrivSubnets --> EKS
    EKS --> Nodes["Managed Node Group"]
    Nodes --> ArgoCD["ArgoCD Control Plane"]
```

### GitOps Delivery Flow (Target State)

```mermaid
flowchart LR
    Dev["Developer"] -->|"git push"| GH["GitHub Repository"]
    GH -->|"watched by"| ArgoCD["ArgoCD on EKS"]
    ArgoCD -->|"sync"| Apps["Deployed Applications"]
    Apps -.->|"state reported"| ArgoCD
    ArgoCD -.->|"self-heal & drift detection"| Apps
```
Setting up resources for multi cluster gitops

versions.tf 

bash 
```
terraform {
  required_version = "~> 1.15.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.2"
    }
  }
}
```

required_version ensures everyone uses a compatible Terraform version.
required_providers pins the AWS provider to a compatible major version while allowing minor updates.

providers.tf

bash
```
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
```

variables.tf

bash
```
variable "aws_region" {
  description = "AWS Region"

  type = string
}

variable "project_name" {
  description = "Project Name"

  type = string
}

variable "environment" {
  description = "Environment"

  type = string
}

variable "owner" {
  description = "Resource Owner"

  type = string
}
```
These are the global variables that every module will use.

bash
```
aws_region  = "us-east-1"

project_name = "argocd-multicluster"

environment = "management"

owner = "Rabindranath"
```
This keeps environment-specific values separate from the module code.

remote backend config

bash
```
terraform {
  backend "s3" {
    bucket       = "tfstate-rabindranath-argocd-multicluster"
    key          = "management/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
```

<img width="2734" height="1466" alt="image" src="https://github.com/user-attachments/assets/c1d9aabe-2a0c-45da-a8b0-8994ec9e5f96" />

# Phase 2 – VPC Module

adding more variables in modules/vpc/variables.tf

bash
```
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR Block"
  type        = string
}
```

locals.tf

bash
```
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "VPC"
  }
}
```
modules/vpc/main.tf

bash
```
resource "aws_vpc" "this" {

  cidr_block = var.vpc_cidr

  enable_dns_support = true

  enable_dns_hostnames = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}
```

modules/vpc/outputs.tf

bash
```
output "vpc_id" {
  description = "VPC ID"

  value = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR"

  value = aws_vpc.this.cidr_block
}
```

adding environment variables in /environments/management/variables.tf

bash
```
variable "vpc_cidr" {
  description = "Management VPC CIDR"

  type = string
}
```
/environments/management/terraform.tfvars
bash
```
vpc_cidr = "10.0.0.0/16"
```
calling the module

bash
```
module "vpc" {

  source = "../../modules/vpc"

  project_name = var.project_name

  environment = var.environment

  vpc_cidr = var.vpc_cidr
}
```

exposing outputs

bash
```
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr" {
  value = module.vpc.vpc_cidr
}
```

validating the code and plan

<img width="2938" height="1612" alt="image" src="https://github.com/user-attachments/assets/889d0d83-b798-42b3-b6a4-179afb25da74" />

applying  changes

<img width="2486" height="1406" alt="image" src="https://github.com/user-attachments/assets/157101ee-4d3d-4ca2-9344-36941cf7ea48" />


Internet Gateway (IGW) 

modules/vpc/main.tf

bash
```
############################################
# Internet Gateway
############################################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )
}
```
modules/vpc/outputs.tf

bash
```
output "internet_gateway_id" {
  description = "Internet Gateway ID"

  value = aws_internet_gateway.this.id
}
```
terraform/environments/management/outputs.tf

bash
```
output "internet_gateway_id" {
  value = module.vpc.internet_gateway_id
}
```

verify and apply

bash
```
terraform fmt -recursive
terraform validate
terraform plan
```
terraform apply and outputs


<img width="2360" height="1004" alt="image" src="https://github.com/user-attachments/assets/0056fa7d-2bbe-48c9-bb16-4fde8f731c59" />

setting up public subnets

modules/vpc/variables.tf
bash
```
variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability Zones"
  type        = list(string)
}
```

terraform.tfvars
bash
```
availability_zones = [
  "us-east-1a",
  "us-east-1b"
]

public_subnet_cidrs = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]
```

environments/management/variables.tf

bash
```
variable "availability_zones" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}
```
In environments/management/main.tf

bash
```
module "vpc" {

  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment

  vpc_cidr = var.vpc_cidr

  availability_zones = var.availability_zones

  public_subnet_cidrs = var.public_subnet_cidrs
}
```
modules/vpc/main.tf

bash
```
############################################
# Public Subnets
############################################

resource "aws_subnet" "public" {

  count = length(var.public_subnet_cidrs)

  vpc_id = aws_vpc.this.id

  cidr_block = var.public_subnet_cidrs[count.index]

  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"

      "kubernetes.io/role/elb" = "1"
    }
  )
}
```
modules/vpc/outputs.tf

bash
```
output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}
```
environments/management/outputs.tf

bash
```
output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}
```

verify and validate ,plan 

<img width="2906" height="1764" alt="image" src="https://github.com/user-attachments/assets/1a969b0f-74f5-4179-ae42-d3098887dc8b" />

Terraform apply

<img width="2520" height="1146" alt="image" src="https://github.com/user-attachments/assets/a1b642a1-fa14-4314-bd0a-ca6099c6dbf0" />

Setting up private subnets ,similiar to public subenets

<img width="2556" height="1476" alt="image" src="https://github.com/user-attachments/assets/6468932e-521f-47c5-b9e2-e283f2c5aaf8" />

Setting up NAT Gateway and Elastic Ip

bash
```
############################################
# Elastic IP for NAT Gateway
############################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-eip"
    }
  )
}
```
make chnages in output.tf and validate ,plan and apply

<img width="2326" height="1256" alt="image" src="https://github.com/user-attachments/assets/50d63b83-4727-433e-95c7-0023c2607111" />

NAT gateway

bash
```
############################################
# NAT Gateway
############################################

resource "aws_nat_gateway" "this" {

  allocation_id = aws_eip.nat.id

  subnet_id = aws_subnet.public[0].id

  connectivity_type = "public"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat"
    }
  )

  depends_on = [
    aws_internet_gateway.this
  ]
}
```
<img width="2864" height="1758" alt="image" src="https://github.com/user-attachments/assets/c418d338-a372-46fd-a935-6feee14acc07" />


setting Route tables and sssociate to respective subnets

bash
```
resource "aws_vpc" "this" {

  cidr_block = var.vpc_cidr

  enable_dns_support = true

  enable_dns_hostnames = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}
############################################
# Internet Gateway
############################################

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )
}
############################################
# Public Subnets
############################################

resource "aws_subnet" "public" {

  count = length(var.public_subnet_cidrs)

  vpc_id = aws_vpc.this.id

  cidr_block = var.public_subnet_cidrs[count.index]

  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"

      "kubernetes.io/role/elb" = "1"
    }
  )
}
############################################
# Private Subnets
############################################

resource "aws_subnet" "private" {

  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.this.id

  cidr_block = var.private_subnet_cidrs[count.index]

  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = false

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-${count.index + 1}"

      "kubernetes.io/role/internal-elb" = "1"
    }
  )
}
############################################
# Elastic IP for NAT Gateway
############################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-eip"
    }
  )
}
############################################
# NAT Gateway
############################################

resource "aws_nat_gateway" "this" {

  allocation_id = aws_eip.nat.id

  subnet_id = aws_subnet.public[0].id

  connectivity_type = "public"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat"
    }
  )

  depends_on = [
    aws_internet_gateway.this
  ]
}
############################################
# Public Route Table
############################################

resource "aws_route_table" "public" {

  vpc_id = aws_vpc.this.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-rt"
    }
  )
}
############################################
# Internet Route
############################################

resource "aws_route" "public_internet" {

  route_table_id = aws_route_table.public.id

  destination_cidr_block = "0.0.0.0/0"

  gateway_id = aws_internet_gateway.this.id
}

############################################
# Private Route Table
############################################

resource "aws_route_table" "private" {

  vpc_id = aws_vpc.this.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-rt"
    }
  )
}

############################################
# NAT Route
############################################

resource "aws_route" "private_nat" {

  route_table_id = aws_route_table.private.id

  destination_cidr_block = "0.0.0.0/0"

  nat_gateway_id = aws_nat_gateway.this.id
}

############################################
# Public Route Table Association
############################################

resource "aws_route_table_association" "public" {

  count = length(aws_subnet.public)

  subnet_id = aws_subnet.public[count.index].id

  route_table_id = aws_route_table.public.id
}

############################################
# Private Route Table Association
############################################

resource "aws_route_table_association" "private" {

  count = length(aws_subnet.private)

  subnet_id = aws_subnet.private[count.index].id

  route_table_id = aws_route_table.private.id
}
```

validate and plan , apply

<img width="2800" height="1710" alt="image" src="https://github.com/user-attachments/assets/4e439aab-1f17-47c9-9826-06269cb32ad6" />


# Phase 3 – IAM

Create all IAM resources required for EKS.

AWS IAM
│
├── EKS Cluster Role
│
├── EKS Node Role
│
├── Trust Policies
│
└── AWS Managed Policy Attachments

modules/iam/variables.tf

bash
```
variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}
```

EKS Cluster IAM Role → Allows the EKS control plane to communicate with AWS services on your behalf.

              AWS EKS Service
                     │
          sts:AssumeRole
                     │
                     ▼
         EKS Cluster IAM Role
                     │
                     ▼
          AWS Managed Policies

bash
```
############################################
# EKS Cluster Trust Policy
############################################

data "aws_iam_policy_document" "eks_cluster_assume_role" {

  statement {

    effect = "Allow"

    principals {

      type = "Service"

      identifiers = [
        "eks.amazonaws.com"
      ]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}
############################################
# EKS Cluster IAM Role
############################################

resource "aws_iam_role" "eks_cluster" {

  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-cluster-role"
    }
  )
}
```

<img width="2826" height="1616" alt="image" src="https://github.com/user-attachments/assets/0fd90258-161a-4975-ba59-0060f5c94f0f" />

verify

<img width="2462" height="1062" alt="image" src="https://github.com/user-attachments/assets/d30edacd-fb1a-4211-a617-eda738ac8156" />


EKS Node IAM Role 

terraform/modules/iam/main.tf

bash
```
############################################
# EKS Node Trust Policy
############################################

data "aws_iam_policy_document" "eks_node_assume_role" {

  statement {

    effect = "Allow"

    principals {

      type = "Service"

      identifiers = [
        "ec2.amazonaws.com"
      ]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

############################################
# EKS Node IAM Role
############################################

resource "aws_iam_role" "eks_node" {

  name = "${var.project_name}-${var.environment}-eks-node-role"

  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-eks-node-role"
    }
  )
}

```

<img width="2692" height="1414" alt="image" src="https://github.com/user-attachments/assets/a9f7f490-626a-4f8e-975d-73b0eca24503" />

Attach the required AWS managed policies to the IAM roles.

terraform/modules/iam/main.tf

bash
```

# EKS Cluster Policy Attachment


resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {

  role = aws_iam_role.eks_cluster.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


# Worker Node Policy


resource "aws_iam_role_policy_attachment" "eks_node_worker_policy" {

  role = aws_iam_role.eks_node.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

############################################
# ECR Pull Policy
############################################

resource "aws_iam_role_policy_attachment" "eks_node_ecr_policy" {

  role = aws_iam_role.eks_node.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
}

############################################
# VPC CNI Policy
############################################

resource "aws_iam_role_policy_attachment" "eks_node_cni_policy" {

  role = aws_iam_role.eks_node.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
```
terraform validate,plan ,apply

bash
```
aws iam list-attached-role-policies \
  --role-name argocd-multicluster-management-eks-cluster-role

aws iam list-attached-role-policies \
  --role-name argocd-multicluster-management-eks-node-role

```



<img width="2746" height="1796" alt="image" src="https://github.com/user-attachments/assets/3f0e1f04-1770-45e8-bb8f-52afa9e18671" />

bash
```

                 AWS
                  │
      ┌───────────┴───────────┐
      ▼                       ▼
EKS Control Plane      EC2 Worker Nodes
      │                       │
      ▼                       ▼
 Cluster IAM Role       Node IAM Role
      │                       │
      ▼                       ▼
 AmazonEKSClusterPolicy  AmazonEKSWorkerNodePolicy
                          AmazonEC2ContainerRegistryPullOnly
                          AmazonEKS_CNI_Policy

```

# Phase 4 – EKS Cluster

terraform/environments/management/main.tf

bash
```
module "eks" {
  source = "../../modules/eks"

  project_name = var.project_name
  environment  = var.environment

  cluster_role_arn  = module.iam.cluster_role_arn
  private_subnet_ids = module.vpc.private_subnet_ids
}
```

terraform/modules/iam/main.tf
bash
```
############################################
# EKS Cluster
############################################

resource "aws_eks_cluster" "this" {

  name = "${var.project_name}-${var.environment}"

  role_arn = var.cluster_role_arn

  version = "1.33"

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  vpc_config {

    subnet_ids = var.private_subnet_ids

    endpoint_private_access = true

    endpoint_public_access = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}"
    }
  )
}
```

<img width="2652" height="1206" alt="image" src="https://github.com/user-attachments/assets/fb1ce7b4-0273-4e68-82f7-bded41d70df0" />

Verify EKS cluster

bash
```
aws eks update-kubeconfig \
  --name argocd-multicluster-management \
  --region us-east-1

  kubectl get nodes
```

<img width="2940" height="426" alt="image" src="https://github.com/user-attachments/assets/edfd316e-1a31-469c-8133-93b7d13b8087" />

Phase 5 – Managed Node Group

Create an AWS Managed Node Group.

AWS will automatically:

Launch EC2 instances
Join them to the cluster
Replace unhealthy nodes
Handle upgrades


bash
```
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "node_role_arn" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}
```

terraform/environments/management/main.tf

bash
```
module "node_group" {
  source = "../../modules/node-group"

  project_name = var.project_name
  environment  = var.environment

  cluster_name      = module.eks.cluster_name
  node_role_arn     = module.iam.node_role_arn
  private_subnet_ids = module.vpc.private_subnet_ids
}
```
terraform/modules/node-group/main.tf

bash
```
############################################
# EKS Managed Node Group
############################################

resource "aws_eks_node_group" "this" {

  cluster_name = var.cluster_name

  node_group_name = "${var.project_name}-${var.environment}-nodes"

  node_role_arn = var.node_role_arn

  subnet_ids = var.private_subnet_ids

  ami_type = "AL2023_x86_64_STANDARD"

  capacity_type = "ON_DEMAND"

  instance_types = [
    "t3.medium"
  ]

  scaling_config {

    desired_size = 2

    min_size = 2

    max_size = 3
  }

  update_config {
    max_unavailable = 1
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-node-group"
    }
  )
}
```
<img width="2730" height="1302" alt="image" src="https://github.com/user-attachments/assets/9df97745-4fb0-4a2a-8be7-edb6490855ac" />

bash
```
aws eks update-kubeconfig \
  --region us-east-1 \
  --name argocd-multicluster-management

  kubectl get nodes
```

<img width="2938" height="452" alt="image" src="https://github.com/user-attachments/assets/3656e98b-32c1-424d-9afc-ef0748291520" />

Configuring  EKS Add-ons

Install the AWS-managed EKS add-ons required for a production-ready cluster.

VPC CNI – Pod networking
CoreDNS – Cluster DNS
kube-proxy – Kubernetes networking
EBS CSI Driver – Dynamic EBS volume provisioning

These are managed by AWS, so upgrades are much easier.

bash
```
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = var.cluster_name
  addon_name   = "vpc-cni"
}

resource "aws_eks_addon" "coredns" {
  cluster_name = var.cluster_name
  addon_name   = "coredns"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = var.cluster_name
  addon_name   = "kube-proxy"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name = var.cluster_name
  addon_name   = "aws-ebs-csi-driver"
}
```

validate ,plan ,apply

<img width="2530" height="1248" alt="image" src="https://github.com/user-attachments/assets/6ce8f881-d149-41c2-ae55-0ca721bd4f32" />


Prepare EKS for GitOps

Before installing ArgoCD, there are two production prerequisites:

✅ OIDC Provider
✅ IRSA (IAM Roles for Service Accounts)

check OIDC

bash
```
aws eks describe-cluster \
  --name argocd-multicluster-management \
  --region us-east-1 \
  --query "cluster.identity.oidc.issuer" \
  --output text
```
<img width="2434" height="342" alt="image" src="https://github.com/user-attachments/assets/67512491-3951-4d72-b42a-098ed026aa11" />


associate OIDC

bash
```
eksctl utils associate-iam-oidc-provider \
  --cluster argocd-multicluster-management \
  --region us-east-1 \
  --approve
```
<img width="2886" height="392" alt="image" src="https://github.com/user-attachments/assets/83b982c5-a39f-4d0e-a2b3-bb425b7e1618" />

<img width="2878" height="458" alt="image" src="https://github.com/user-attachments/assets/110dff69-7769-45a5-9e0f-83183d361c41" />

IRSA (IAM Roles for Service Accounts)

IRSA allows a Kubernetes ServiceAccount to securely assume an AWS IAM role without storing AWS access keys inside pods.

Create the IRSA Trust Policy

We'll create an IAM role that only the EBS CSI Controller ServiceAccount can assume.

bash
```
############################################
# EBS CSI IRSA Trust Policy
############################################

data "aws_iam_policy_document" "ebs_csi_irsa" {

  statement {

    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        var.oidc_provider_arn
      ]
    }

    condition {

      test = "StringEquals"

      variable = "${replace(var.oidc_issuer_url, "https://", "")}:sub"

      values = [
        "system:serviceaccount:kube-system:ebs-csi-controller-sa"
      ]
    }

    condition {

      test = "StringEquals"

      variable = "${replace(var.oidc_issuer_url, "https://", "")}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }
  }
}
############################################
# EBS CSI IRSA Role
############################################

resource "aws_iam_role" "ebs_csi_irsa" {

  name = "${var.project_name}-${var.environment}-ebs-csi-irsa"

  assume_role_policy = data.aws_iam_policy_document.ebs_csi_irsa.json

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ebs-csi-irsa"
    }
  )
}
```

Updating a iam module with OIDC details

bash
```
module "iam" {

  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment

  oidc_provider_arn = "arn:aws:iam::497508796460:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/04BBFEC0FAB11A298B9DF4E58E7D8057"

  oidc_issuer_url = module.eks.oidc_issuer_url
}
```

<img width="2668" height="1574" alt="image" src="https://github.com/user-attachments/assets/10012414-eb5e-41e4-b6f1-244959b749b0" />

Attach the AWS Managed Policy

bash
```
############################################
# EBS CSI Driver Policy
############################################

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {

  role = aws_iam_role.ebs_csi_irsa.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
```

validate ,plan and apply

verify

bash
```
aws iam list-attached-role-policies \
  --role-name argocd-multicluster-management-ebs-csi-irsa
```

<img width="2618" height="532" alt="image" src="https://github.com/user-attachments/assets/31a83fbb-595e-4205-b966-c5678c667f96" />


Install EBS CSI Driver with IRSA

Tell EKS to use the IRSA role we just created when running the EBS CSI Controller.

terraform/modules/addons/main.tf

bash
```
resource "aws_eks_addon" "ebs_csi" {

  cluster_name = var.cluster_name

  addon_name = "aws-ebs-csi-driver"

  service_account_role_arn = var.ebs_csi_irsa_role_arn

  resolve_conflicts_on_create = "OVERWRITE"

  resolve_conflicts_on_update = "OVERWRITE"
}
```

terraform/environments/management/main.tf

bash
```
module "addons" {

  source = "../../modules/addons"

  cluster_name = module.eks.cluster_name

  ebs_csi_irsa_role_arn = module.iam.ebs_csi_irsa_role_arn
}
```

validate plan and apply

verify

bash
```
aws eks describe-addon \
  --cluster-name argocd-multicluster-management \
  --addon-name aws-ebs-csi-driver \
  --region us-east-1
```

<img width="2940" height="1412" alt="image" src="https://github.com/user-attachments/assets/e4ceb940-7a9c-4963-bf4a-9900f81fc388" />

# Install ArgoCD

Install ArgoCD into the management EKS cluster.

1. check the current context and create a namespace argocd

bash
```
kubectl create namespace argocd
```

 We keep ArgoCD isolated from application workloads.

This makes it easier to:

Upgrade ArgoCD
Back it up
Troubleshoot it
Manage RBAC

add helm repo and update 
bash
```
helm repo add argo https://argoproj.github.io/argo-helm

helm repo update
```

verify the repo

bash
```
helm search repo argo/argo-cd
```

<img width="2846" height="618" alt="image" src="https://github.com/user-attachments/assets/4b133a76-c08e-4bd4-8d47-1d087538553d" />

Install ArgoCD

bash
```
helm install argocd argo/argo-cd \
  --namespace argocd
```

<img width="2912" height="894" alt="image" src="https://github.com/user-attachments/assets/e3a2fc17-b9bc-4022-a199-e518ac6b8223" />

verfiy helm release and pods in argocd

bash
```
helm list -n argocd

kubectl get pods -n argocd
```

<img width="2940" height="650" alt="image" src="https://github.com/user-attachments/assets/54bc9239-ac54-4d8b-b0d5-8a787cddd2f1" />

expose argocd to UI

bash
```
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

get password to login 

bash
```
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 --decode
```
user as admin

<img width="2940" height="1378" alt="image" src="https://github.com/user-attachments/assets/21cd7993-5162-4206-adaa-3fb11953d2ec" />

#  Phase 6 Multi-Cluster Management

Create 4 Kind clusters( instead of EKS clusters costs more , creating a local setup) and register them with the management EKS cluster running ArgoCD.

Installing kind

bash
```
brew install kind
```

<img width="2940" height="886" alt="image" src="https://github.com/user-attachments/assets/fbb1903a-1cd6-471e-949b-1dd27dc02fe6" />

create a cluster

bash
```
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

networking:
  disableDefaultCNI: false

nodes:
  - role: control-plane
  - role: worker
  - role: worker
```
creating dev cluster

bash
```
kind create cluster \
  --name dev \
  --config kind-config.yaml
```

<img width="2844" height="844" alt="image" src="https://github.com/user-attachments/assets/7f65c5dc-5b3c-4c8b-b4e3-86ca50527fcd" />

checking the context
bash
```
kubectl config get-contexts
```

<img width="2938" height="412" alt="image" src="https://github.com/user-attachments/assets/ed2947a1-2d83-4237-9c08-3b63b38aa009" />

switchig  to dev cluster

bash
```
kubectl config use-context kind-dev
```

verify the nodes in dev cluster

<img width="1930" height="322" alt="image" src="https://github.com/user-attachments/assets/caeb60a6-7cbe-4359-9dec-033754d6acde" />

we'll create QA, Stage, and Prod using the exact same configuration.

bash
```
kind create cluster --name qa --config kind-config.yaml

kind create cluster --name stage --config kind-config.yaml

kind create cluster --name prod --config kind-config.yaml
```

verfiy the kind clusters
bash
```
kind get clusters
```
<img width="2074" height="320" alt="image" src="https://github.com/user-attachments/assets/57d5b8bf-1736-4e0c-8cd7-552aed2842b1" />

verfiy the contexts

<img width="2940" height="670" alt="image" src="https://github.com/user-attachments/assets/519494ed-883e-4223-9ee9-1da195712fb6" />

Verfiy the nodes in each cluster

bash
```
kubectl --context kind-dev get nodes

kubectl --context kind-qa get nodes

kubectl --context kind-stage get nodes

kubectl --context kind-prod get nodes
```

<img width="2470" height="1150" alt="image" src="https://github.com/user-attachments/assets/7a683125-2051-4b94-a1ba-b4e3c1aefd9c" />

# Register the Kind Clusters with ArgoCD

The current context would be management cluster

bash
```
```

<img width="2926" height="530" alt="image" src="https://github.com/user-attachments/assets/0fc93693-3c04-43cd-a9bd-0888b6a78179" />

not able to register

argo cd server is running inside EKS. When it tries to reach 127.0.0.1, it's trying to reach itself inside the pod, not my laptop. That's why argocd cluster add failed.

Now we can't able to connect from management eks cluster we cna try to setup management cluster in kind


bash
```
kind create cluster \
  --name management \
  --config kind-config.yaml
```
<img width="2940" height="1030" alt="image" src="https://github.com/user-attachments/assets/66af43b8-bb12-4497-9f77-697b8ff19978" />
I also noticed

You currently have:

✅ 4 Kind clusters
✅ 12 Kind nodes
✅ 2 Docker Compose containers
✅ Docker Desktop running
✅ EKS cluster

That's 15+ containers already running.

If Docker Desktop is limited to 4 GB RAM, creating the fifth cluster (Management) often fails exactly like this.
verfiy clusters and contexts

bash
```
docker info | grep -E "CPUs|Total Memory"

docker system df

```
<img width="2444" height="582" alt="image" src="https://github.com/user-attachments/assets/01a13de7-1acd-49d6-a3d5-14e5399dfacf" />


changing resources

<img width="2840" height="1506" alt="image" src="https://github.com/user-attachments/assets/0f991310-6d61-4c6d-b769-1eeb6ce3d92a" />

apply and restart docker


remove the existing cluster and create again

<img width="2642" height="988" alt="image" src="https://github.com/user-attachments/assets/fe86ffbe-5484-46db-b0ef-36b09e9fc4ea" />


bash
```
kind get clusters

kubectl config get-contexts
```
Install ArgoCD on the Management Kind Cluster( not able to use previously created argocd in EKS)

<img width="2896" height="1068" alt="image" src="https://github.com/user-attachments/assets/da28a453-ca59-4a95-a067-ae9f411fd212" />

bash
```
kubectl get pods -n argocd
```

Not able to connect to management cluster API due to memory issue so chnaging kind-config.yaml

bash

```
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4

nodes:
- role: control-plane
```

creating with minimal no of nodes

bash
```
kind create cluster --name management --config kind-config.yaml

kind create cluster --name dev --config kind-config.yaml

kind create cluster --name qa --config kind-config.yaml

kind create cluster --name stage --config kind-config.yaml

kind create cluster --name prod --config kind-config.yaml
```

verfiy clusters

<img width="2940" height="1072" alt="image" src="https://github.com/user-attachments/assets/151c3dfe-3c87-4c1e-94cf-d227a0418e48" />

switch to kind management

bash
  ```
kubectl config use-context kind-management
```

then install argo cd

<img width="2940" height="1410" alt="image" src="https://github.com/user-attachments/assets/c83dcab2-d6f9-4880-a556-0c380bdfbdda" />

port forward

bash
```
kubectl port-forward svc/argocd-server -n argocd 8080:443
```
not able  register the kind clusters to argo cd to local networking limitation

<img width="2940" height="834" alt="image" src="https://github.com/user-attachments/assets/2be4afe2-f253-4e55-947f-179bffc9c1a3" />

## Kind

Learned a valuable limitation:

Default Kind clusters expose the Kubernetes API using localhost.

This works for local `kubectl` but not for a management cluster attempting to manage other Kind clusters.

Better way to implement ArgoCd in EKS we are going to do that but it s cost sensitive

