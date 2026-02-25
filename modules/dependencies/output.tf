output "dependencies_ready"{
    description = "Todas as dependências foram verificadas e Instaladas"
    value = "Todas as dependências verificadas e instaladas!"

    depends_on = [
        null_resource.check_docker,
        null_resource.check_kubectl,
        null_resource.check_kind,
        null_resource.check_helm
    ]
}

output "installed_tools" {
    description = "Ferramentas que foram instaladas"
    value = {
        docker = "Docker"
        kubectl = "Kubectl"
        kind = "Kind"
        helm = "Helm"
    }

    depends_on = [
        null_resource.check_docker,
        null_resource.check_kubectl,
        null_resource.check_kind,
        null_resource.check_helm
    ]
}