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

############################################
# EBS CSI Driver Policy
############################################

resource "aws_iam_role_policy_attachment" "ebs_csi_policy" {

  role = aws_iam_role.ebs_csi_irsa.name

  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
