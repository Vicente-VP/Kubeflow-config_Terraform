output "nvidia_status" {
  description = "Status da GPU NVIDIA"
  value       = "Verificação de GPU NVIDIA concluída"
  
  depends_on = [null_resource.check_nvidia-smi]
}