module "dependencies" {
  source = "./modules/dependencies"
}

module "gpu" {
  source = "./modules/gpu"

  depends_on = [modules.dependencies]
}

module "cluster" {
  source = "./modules/cluster"

  depends_on = [modules.gpu]

    cluster_name = var.kubeflow
}