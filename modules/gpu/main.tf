# modules/gpu/main.tf
locals {
  is_windows = substr(pathexpand("~"), 0, 1) == "/" ? false : true
  is_linux   = !local.is_windows
  
  # Verificar GPU NVIDIA e drivers
  nvidia_cmd_linux = <<-EOT
    #!/bin/bash
    echo "Verificando presença da GPU NVIDIA..."
    
    if lspci | grep -i nvidia > /dev/null 2>&1; then
      echo "GPU NVIDIA detectada!"
      
      if command -v nvidia-smi &> /dev/null; then
        echo "Drivers NVIDIA já instalados!"
        nvidia-smi --query-gpu=name --format=csv,noheader
      else 
        echo "Drivers NVIDIA não encontrados! Instalando..."
        
        if [ -f /etc/os-release ]; then 
          . /etc/os-release
          OS=$ID
        fi

        case $OS in 
          ubuntu|debian)
            sudo apt update
            sudo apt install -y ubuntu-drivers-common
            sudo ubuntu-drivers autoinstall
            echo "Drivers NVIDIA instalados! REINICIE o sistema."
            ;;
          centos|rhel|fedora)
            sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
            sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo
            sudo dnf module install -y nvidia-driver:latest-dkms
            echo "Drivers NVIDIA instalados! REINICIE o sistema."
            ;;
          *)
            echo "Distribuição não suportada. Instale manualmente:"
            echo "https://www.nvidia.com/Download/index.aspx"
            ;;
        esac
      fi
    else 
      echo "Nenhuma GPU NVIDIA detectada no sistema."
    fi 
  EOT
  
  nvidia_cmd_windows = <<-EOT
    Write-Host "Verificando presença de GPU NVIDIA..." -ForegroundColor Cyan

    $$nvidia = Get-WmiObject Win32_VideoController | Where-Object { $$_.Name -like "*NVIDIA*" }

    if ($$nvidia) {
      Write-Host "GPU NVIDIA detectada: $$($$nvidia.Name)" -ForegroundColor Green 

      if (Get-Command nvidia-smi -ErrorAction SilentlyContinue) {
        Write-Host "Drivers NVIDIA já instalados!" -ForegroundColor Green 
        nvidia-smi --query-gpu=name --format=csv,noheader
      } else {
        Write-Host "Drivers NVIDIA não encontrados!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Por favor, instale os drivers NVIDIA manualmente:" -ForegroundColor Yellow
        Write-Host "1. Acesse: https://www.nvidia.com/Download/index.aspx" -ForegroundColor Cyan
        Write-Host "2. Selecione seu modelo de GPU: $$($$nvidia.Name)" -ForegroundColor Cyan
        Write-Host "3. Baixe e instale o driver recomendado" -ForegroundColor Cyan
        Write-Host "4. REINICIE o computador" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Ou use GeForce Experience para atualização automática:" -ForegroundColor Yellow
        Write-Host "https://www.nvidia.com/pt-br/geforce/geforce-experience/" -ForegroundColor Cyan 
      }
    } else {
      Write-Host "Nenhuma GPU NVIDIA detectada no sistema." -ForegroundColor Gray
    }
  EOT
  
  # NVIDIA Container Toolkit
  toolkit_cmd_linux = <<-EOT
    #!/bin/bash
    
    if command -v nvidia-smi &> /dev/null; then
      echo "Configurando NVIDIA Container Toolkit para Docker..."
      
      if ! command -v nvidia-ctk &> /dev/null; then
        echo "NVIDIA Container Toolkit não encontrado! Instalando..."
        
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
          sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.list | \
          sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
          sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        
        sudo apt update
        sudo apt install -y nvidia-container-toolkit
        
        sudo nvidia-ctk runtime configure --runtime=docker
        sudo systemctl restart docker
        
        echo "NVIDIA Container Toolkit instalado!"
      else
        echo "NVIDIA Container Toolkit já instalado!"
      fi
      
      echo "Testando acesso à GPU no container..."
      docker run --rm --gpus all nvidia/cuda:12.3.2-base-ubuntu22.04 nvidia-smi
      
      echo ""
      echo "GPU configurada com sucesso no Docker!"
    else
      echo "Driver NVIDIA não detectado (nvidia-smi não encontrado)."
      echo "   Instale o driver NVIDIA antes de configurar o Container Toolkit."
    fi
  EOT
  
  toolkit_cmd_windows = <<-EOT
    Write-Host "NVIDIA Container Toolkit não é necessário no Windows." -ForegroundColor Yellow
    Write-Host "O Docker Desktop for Windows gerencia GPUs automaticamente." -ForegroundColor Cyan
  EOT
}

# Verificar GPU NVIDIA e drivers
resource "null_resource" "check_nvidia" {
  provisioner "local-exec" {
    command     = local.is_linux ? local.nvidia_cmd_linux : local.nvidia_cmd_windows
    interpreter = local.is_linux ? ["bash", "-c"] : ["PowerShell", "-Command"]
    on_failure  = continue
  }
}

# Instalar NVIDIA Container Toolkit
resource "null_resource" "check_nvidia_toolkit" {
  depends_on = [null_resource.check_nvidia]
  
  provisioner "local-exec" {
    command     = local.is_linux ? local.toolkit_cmd_linux : local.toolkit_cmd_windows
    interpreter = local.is_linux ? ["bash", "-c"] : ["PowerShell", "-Command"]
    on_failure  = continue
  }
}