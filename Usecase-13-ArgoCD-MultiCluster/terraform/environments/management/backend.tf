terraform {
  backend "s3" {
    bucket       = "tfstate-rabindranath-argocd-multicluster"
    key          = "management/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
