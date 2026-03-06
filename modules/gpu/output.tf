output "nvidia_status" {
  description = "Status da GPU NVIDIA"
  value       = "Verificação de GPU NVIDIA concluída"
  
  depends_on = [null_resource.check_nvidia]
  depends_on = [null_resource.check_nvidia_toolkit]
}

output "installed" {
    description = "O que foi Instalado em relação a GPU"
    value = {
        nvidia = "Drivers"
        toolkit = "Nvidia-Toolkit"
    }

    depends_on = [
        null_resource.check_nvidia,
        null_resource.check_nvidia_toolkit,
    ]
}