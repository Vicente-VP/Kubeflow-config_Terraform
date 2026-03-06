locals {
    is_windows = substr(pathexpand("~"), 0, 1) == "/" ? false : true
    is_linux   = !local.is_windows

    create_cluster_cmd_linux = <<-EOT
        #!/bin/bash
        echo "Criando cluster Kubernetes com Kind..."
        if ! command -v kind &> /dev/null; then
          echo "Kind não encontrado! Instale o Kind primeiro."
          exit 1
        fi

        if kind get clusters | grep -q "^${var.kubeflow}$"; then
          echo "Cluster '${var.kubeflow}' já existe!"
          echo "Usando cluster existente."
        else
          kind create cluster --name=${var.kubeflow} --config=${path.module}/cluster.yaml
          echo "Cluster criado com sucesso!"
        fi
        kubectl cluster-info --context kind-${var.kubeflow}
    EOT

    create_cluster_cmd_windows = <<-EOT
        Write-Host "Criando cluster Kubernetes com Kind..." -ForegroundColor Cyan
        
        if (-not (Get-Command kind -ErrorAction SilentlyContinue)) {
          Write-Host "Kind não encontrado! Instale o Kind primeiro." -ForegroundColor Red
          exit 1
        }
        
        $$clusterExists = kind get clusters | Select-String -Pattern "^$${var.kubeflow}$$" -Quiet
        
        if ($$clusterExists) {
          Write-Host "Cluster '$${var.kubeflow}' já existe!" -ForegroundColor Yellow
          Write-Host "   Usando cluster existente." -ForegroundColor Gray
        } else {
          kind create cluster --name=$${var.kubeflow} --config="$${path.module}/cluster.yaml"
          Write-Host "Cluster criado com sucesso!" -ForegroundColor Green
        }
        
        kubectl cluster-info --context kind-$${var.kubeflow}
    EOT

    operator_cmd_linux = <<-EOT
        #!/bin/bash
        echo "Verificando pré-requisitos para GPU Operator..."

        if ! command -v helm &> /dev/null; then
          echo "Helm não encontrado! Instale o Helm primeiro."
          exit 1
        fi

        if ! kubectl cluster-info &> /dev/null; then
          echo "Cluster Kubernetes não encontrado ou não acessível."
          exit 1
        fi

        if ! command -v nvidia-smi &> /dev/null; then
          echo "Driver NVIDIA não encontrado."
          echo "GPU Operator pode instalar drivers, mas é recomendado ter drivers no host."
        fi

        echo ""
        echo "Instalando NVIDIA GPU Operator..."

        echo "Adicionando repositório Helm da NVIDIA..."
        helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
        helm repo update

        echo "Criando namespace gpu-operator..."
        kubectl create namespace gpu-operator --dry-run=client -o yaml | kubectl apply -f -
        kubectl label namespace gpu-operator pod-security.kubernetes.io/enforce=privileged --overwrite

        if helm list -n gpu-operator | grep -q gpu-operator; then
          echo "GPU Operator já está instalado!"
        else
          echo "Instalando GPU Operator v25.10.1..."
          echo "(isso pode demorar alguns minutos...)"

          helm install --wait --generate-name \
            -n gpu-operator --create-namespace \
            nvidia/gpu-operator \
            --version=v25.10.1 \
            --set driver.enabled=false \
            --timeout=10m

          echo "GPU Operator instalado com sucesso!"
        fi

     echo ""
        echo "Verificando instalação..."
        echo ""
        echo "Pods no namespace gpu-operator:"
        kubectl get pods -n gpu-operator

        echo ""
        echo "Nós rotulados para GPUs:"
        kubectl get nodes --show-labels | grep nvidia || echo "Labels NVIDIA ainda não aplicados (aguarde alguns minutos)"

        echo ""
        echo "NVIDIA GPU Operator configurado!"
        echo ""
        echo "A: O Kind NÃO tem suporte nativo a GPUs."
        echo "Esta configuração funciona em clusters reais (bare metal, VMs com GPU passthrough)."
    EOT

    operator_cmd_windows = <<-EOT
        Write-Host "NVIDIA GPU Operator é para Linux/Kubernetes." -ForegroundColor Yellow
        Write-Host "Em Windows com Kubernetes, use Docker Desktop com suporte GPU nativo." -ForegroundColor Cyan
    EOT
}

resource "null_resource" "check_cluster" {
  provisioner "local-exec" {
    command     = local.is_linux ? local.create_cluster_cmd_linux : local.create_cluster_cmd_windows
    interpreter = local.is_linux ? ["bash", "-c"] : ["PowerShell", "-Command"]
  }

  provisioner "local-exec" {
    when       = destroy
    command    = local.is_linux ? "kind delete cluster --name=${var.kubeflow}" : "kind delete cluster --name=${var.kubeflow}"
    interpreter = local.is_linux ? ["bash", "-c"] : ["PowerShell", "-Command"]
    on_failure = continue
  }
}

resource "null_resource" "check_cluster" {
  depends_on = [null_resource.check_cluster]
  provisioner "local-exec" {
    command     = local.is_linux ? local.operator_cmd_linux : local.operator_cmd_windows
    interpreter = local.is_linux ? ["bash", "-c"] : ["PowerShell", "-Command"]
  }
}


