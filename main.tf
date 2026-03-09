module "dependencies" {
  source = "./modules/dependencies"
}

module "gpu" {
  source = "./modules/gpu"

  depends_on = [module.dependencies]
}

module "cluster" {
  source = "./modules/cluster"

  depends_on = [module.gpu]

  kubeflow = var.kubeflow
}