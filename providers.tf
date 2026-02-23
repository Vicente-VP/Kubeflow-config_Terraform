provider "null" {}
provider "local" {}
provider "docker" {}
provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
provider "kubernetes" {
  config_path = fileexists("~/.kube/config") ? "~/.kube/config" : null
}