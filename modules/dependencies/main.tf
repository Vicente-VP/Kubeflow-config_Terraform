# modules/dependencies/main.tf

locals {
  is_windows = substr(pathexpand("~"), 0, 1) == "/" ? false : true
  is_linux   = !local.is_windows

  # Docker
  docker_cmd_linux = <<-EOT
    #!/bin/bash
    if ! command -v docker &> /dev/null; then
      echo " Docker não instalado! Instalando agora..."
      curl -fsSL https://get.docker.com | sh
      sudo usermod -aG docker $USER
      echo "Docker instalado com sucesso!"
    else
      echo "Docker já instalado!"
    fi
  EOT

  docker_cmd_windows = <<-EOT
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
      Write-Host "Docker não instalado! Por favor instale manualmente" -ForegroundColor Red
      Write-Host "https://docs.docker.com/desktop/install/windows-install/" -ForegroundColor Cyan
      exit 1
    } else {
      Write-Host " Docker já instalado!" -ForegroundColor Green
    }
  EOT

  # kubectl
  kubectl_cmd_linux = <<-EOT
    #!/bin/bash
    if ! command -v kubectl &> /dev/null; then
      echo " kubectl não instalado! Instalando agora..."
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      chmod +x kubectl
      sudo mv kubectl /usr/local/bin/
      echo "kubectl instalado com sucesso!"
    else
      echo "kubectl já instalado!"
    fi
  EOT

  kubectl_cmd_windows = <<-EOT
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
      Write-Host "kubectl não instalado! Instalando..." -ForegroundColor Yellow
      $version = (Invoke-WebRequest -Uri "https://dl.k8s.io/release/stable.txt" -UseBasicParsing).Content.Trim()
      Invoke-WebRequest -Uri "https://dl.k8s.io/release/$version/bin/windows/amd64/kubectl.exe" -OutFile "C:\Windows\System32\kubectl.exe"
      Write-Host "kubectl instalado com sucesso!" -ForegroundColor Green
    } else {
      Write-Host "kubectl já instalado!" -ForegroundColor Green
    }
  EOT

  # Kustomize
  kustomize_cmd_linux = <<-EOT
    #!/bin/bash
    if ! command -v kustomize &> /dev/null; then
      echo " Kustomize não instalado! Instalando agora..."
      curl -LO https://github.com/kubernetes-sigs/kustomize/releases/latest/download/kustomize_linux_amd64.tar.gz
      tar -xvf kustomize_linux_amd64.tar.gz
      chmod +x kustomize
      sudo mv kustomize /usr/local/bin/
      rm kustomize_linux_amd64.tar.gz
      echo "Kustomize instalado com sucesso!"
    else
      echo "Kustomize já instalado!"
    fi
  EOT

  kustomize_cmd_windows = <<-EOT
    if (-not (Get-Command kustomize -ErrorAction SilentlyContinue)) {
      Write-Host " Kustomize não instalado! Instalando agora..." -ForegroundColor Yellow
      $tag = (Invoke-WebRequest -Uri "https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest" -UseBasicParsing | ConvertFrom-Json).tag_name
      $version = $tag -replace "kustomize/",""
      $url = "https://github.com/kubernetes-sigs/kustomize/releases/download/$tag/kustomize_${version}_windows_amd64.tar.gz"
      Invoke-WebRequest -Uri $url -OutFile "$env:TEMP\kustomize.tar.gz"
      tar -xzf "$env:TEMP\kustomize.tar.gz" -C "$env:TEMP"
      Move-Item -Path "$env:TEMP\kustomize.exe" -Destination "C:\Windows\System32\kustomize.exe" -Force
      Remove-Item "$env:TEMP\kustomize.tar.gz" -Force
      Write-Host "Kustomize instalado com sucesso!" -ForegroundColor Green
    } else {
      Write-Host "Kustomize já instalado!" -ForegroundColor Green
    }
  EOT

  # Kind
  kind_cmd_linux = <<-EOT
    #!/bin/bash
    if ! command -v kind &> /dev/null; then
      echo " Kind não instalado! Instalando agora..."
      curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
      chmod +x kind
      sudo mv kind /usr/local/bin/
      echo "Kind instalado com sucesso!"
    else
      echo "Kind já instalado!"
    fi
  EOT

  kind_cmd_windows = <<-EOT
    if (-not (Get-Command kind -ErrorAction SilentlyContinue)) {
      Write-Host " Kind não instalado! Instalando agora..." -ForegroundColor Yellow
      Invoke-WebRequest -Uri "https://kind.sigs.k8s.io/dl/latest/kind-windows-amd64" -OutFile "C:\Windows\System32\kind.exe"
      Write-Host "Kind instalado com sucesso!" -ForegroundColor Green
    } else {
      Write-Host "Kind já instalado!" -ForegroundColor Green
    }
  EOT

  # Helm
  helm_cmd_linux = <<-EOT
    #!/bin/bash
    if ! command -v helm &> /dev/null; then
      echo " Helm não instalado! Instalando agora..."
      HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
      curl -Lo helm.tar.gz "https://get.helm.sh/helm-$${HELM_VERSION}-linux-amd64.tar.gz"
      tar -zxvf helm.tar.gz
      sudo mv linux-amd64/helm /usr/local/bin/helm
      rm -rf helm.tar.gz linux-amd64
      echo "Helm instalado com sucesso!"
    else
      echo "Helm já instalado!"
    fi
  EOT

  helm_cmd_windows = <<-EOT
    if (-not (Get-Command helm -ErrorAction SilentlyContinue)) {
      Write-Host " Helm não instalado! Instalando agora..." -ForegroundColor Yellow
      $helmVersion = (Invoke-WebRequest -Uri "https://api.github.com/repos/helm/helm/releases/latest" -UseBasicParsing | ConvertFrom-Json).tag_name
      $helmUrl = "https://get.helm.sh/helm-$helmVersion-windows-amd64.zip"
      $helmZip = "$env:TEMP\helm.zip"
      Invoke-WebRequest -Uri $helmUrl -OutFile $helmZip
      Expand-Archive -Path $helmZip -DestinationPath "$env:TEMP\helm" -Force
      Move-Item -Path "$env:TEMP\helm\windows-amd64\helm.exe" -Destination "C:\Windows\System32\helm.exe" -Force
      Remove-Item $helmZip -Force
      Remove-Item "$env:TEMP\helm" -Recurse -Force
      Write-Host "Helm instalado com sucesso!" -ForegroundColor Green
    } else {
      Write-Host "Helm já instalado!" -ForegroundColor Green
    }
  EOT
}

# Docker
resource "null_resource" "check_docker" {
  provisioner "local-exec" {
    command     = local.is_linux ? local.docker_cmd_linux : local.docker_cmd_windows
    interpreter = local.is_linux ? ["bash", "-c"] : ["PowerShell", "-Command"]
  }
}

# kubectl
resource "null_resource" "check_kubectl" {
  depends_on = [null_resource.check_docker]

  provisioner "local-exec" {
    command     = local.is_linux ? local.kubectl_cmd_linux : local.kubectl_cmd_windows
    interpreter = local.is_linux ? ["bash", "-c"] : ["PowerShell", "-Command"]
  }
}

# Kustomize
resource "null_resource" "check_kustomize" {
  depends_on = [null_resource.check_kubectl]

  provisioner "local-exec" {
    command     = local.is_linux ? local.kustomize_cmd_linux : local.kustomize_cmd_windows
    interpreter = local.is_linux ? ["bash", "-c"] : ["PowerShell", "-Command"]
  }
}

# Kind
resource "null_resource" "check_kind" {
  depends_on = [null_resource.check_kustomize]

  provisioner "local-exec" {
    command     = local.is_linux ? local.kind_cmd_linux : local.kind_cmd_windows
    interpreter = local.is_linux ? ["bash", "-c"] : ["PowerShell", "-Command"]
  }
}

# Helm
resource "null_resource" "check_helm" {
  depends_on = [null_resource.check_kind]

  provisioner "local-exec" {
    command     = local.is_linux ? local.helm_cmd_linux : local.helm_cmd_windows
    interpreter = local.is_linux ? ["bash", "-c"] : ["PowerShell", "-Command"]
  }
}