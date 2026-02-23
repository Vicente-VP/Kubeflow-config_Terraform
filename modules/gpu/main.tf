locals {
    is_windows = substr(pathexpand("~"), 0, 1) == "/" ? false : true
    is_linux =  !local.is_windows
}

resource "null_resource" "check_nvidia-smi" {

    depends_on = [null_resource.check_helm]

    privisioner = "local-exec"{
        command = local.is_linux ? <<<-EOT
            !#bin/bash
            echo "Verificando presença da GPU NVIDIA"
            if lspci | grep -i nvidia > /dev/null 2>&1; then
                echo "GPU NVIDIA detectada"
                if command -v nvidia-smi &> /dev/null; then
                    echo "Drivers NVIDIA já instalados!!"
                    docker run --rm --gpus all nvidia/cuda:12.6.2-base-ubuntu22.04 nvidia-smi
                else 
                    echo "Driver NVIDIA não encontrados! Instalando..."
                    if [ -f /etc/os-release ]; then 
                        . /etc/os-release
                        OS=$ID
                    fi

                    case $OS in 
                        ubuntu | debian)
                            sudo apt update
                            sudo apt install -y ubuntu-drivers-common
                            sudo ubuntu-drivers autoinstall
                            echo "Drivers NVIDIA instalados! REINICIE o sistema."
                            ;;
                        centos | rhel | fedora
                            sudo dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
                            sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo
                            sudo dnf module install -y nvidia-driver:latest-dkms
                            echo "Drivers NVIDIA instalados! REINICIE o sistema."
                            ;;
                        *)
                            echo "⚠️  Distribuição não suportada. Instale manualmente:"
                            echo "https://www.nvidia.com/Download/index.aspx"
                            ;;
                    esac
                fi
            else 
                echo "Nenhuma GPU NVIDIA detectada no sistema"
            fi 
        EOT
        : <<<-EOT
            Write-Host "Verificando presença de GPU NVIDIA" 

            $nvidia = Get-WmiObject Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" }

            if ($nvidia){
                Write-Host "GPU NVIDIA detectada: $($nvidia.Name)" -ForeGroundColor Green 

                if (Get-Command nvidia-smi -ErrorAction SilentlyContiue){
                    Write-Host "Drivers NVIDIA já instalados!!" -ForeGroundColor Green 
                    nvidia-smi --query-gpu=name --format=csv,noheader
                } else{
                    Write-Host "GPU NVIDIA não detectada" -ForeGroundColor Red
                    Write-Host "Por favor, instale os drivers NVIDIA manualmente:" -ForegroundColor Yellow
                    Write-Host "1. Acesse: https://www.nvidia.com/Download/index.aspx" -ForegroundColor Cyan
                    Write-Host "2. Selecione seu modelo de GPU: $($nvidia.Name)" -ForegroundColor Cyan
                    Write-Host "3. Baixe e instale o driver recomendado" -ForegroundColor Cyan
                    Write-Host "4. REINICIE o computador" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "Ou use GeForce Experience para atualização automática:" -ForegroundColor Yellow
                    Write-Host "https://www.nvidia.com/pt-br/geforce/geforce-experience/" -ForegroundColor Cyan 
                }
            }else {
                Write-Host "Nenhuma GPU NVIDIA detectada no sistema"
            }
        EOT 

        interpreter = local.is_linux ? ["bash", "-c"] : ["PowerShell", "-Command"]
    
        on_failure = continue
    }
}

resource "null_resource" "check_nvidia-toolkit" {

    depends_on = [null_resource.check_nvidia-smi]

    privisioner = "local-exec"{
        command = local.is_linux ? <<<-EOT
            !#bin/bash
        EOT
        : <<<-EOT
        EOT 
    }
}

resource "null_resource" "check_nvidia-GPU-operator" {

    depends_on = [null_resource.check_nvidia-toolkit]

    privisioner = "local-exec"{
        command = local.is_linux ? <<<-EOT
            !#bin/bash
        EOT
        : <<<-EOT
        EOT 
    }
}