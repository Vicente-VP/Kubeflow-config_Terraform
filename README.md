# Guia da configuração do Terraform
Este repositório contém documentação necessária para entendimento do código de configuração automática do Kubeflow utilizando Terraform.

# Sobre
Guia desenvolvido por pesquisador do Centro Interdisciplinar de Tecnologias Interativas da Universidade de São Paulo (CITI-USP), documentando o processo de configuração automática do Kubeflow utilizando Terraform com foco em otimizar processos.

Vicente Pascoal (@Vicente-VP): Estagiário, Análista e Desenvolvedor de Sistemas - FATEC.

# Estrutura do Repositório
```text
.
├── modules/
│   ├── dependencies/    # Arquivos de instalação e configuração das dependencias
│   ├── gpu/             # Arquivos de instalação e configuração da GPU
│   ├── cluster/             # Arquivos de criação e configuração do Cluster e instalação do Operator
│   ├── kubeflow/             # Arquivos de instalação e configuração do Kubeflow
├── main.tf
├── providers.tf
├── versions.tf
└── README.md
```

# Documentação
#### `modules/dependencies/`
Contém 3 arquivos (`main.tf`, `output.tf`, `variables.tf`), onde o principal é o main.tf que realiza toda a instalação das dependências.

Explicação simples do código: 

Código bash para verificar e instalar a dependência do `kubectl`. Primeiro é feito a verificação se existe ou não o `kubectl`, caso não esteja instalado é feito a instalação automática da dependência 
```terraform
kubectl_cmd_linux = <<-EOT
    #!/bin/bash
    if ! command -v kubectl &> /dev/null; then
      echo "kubectl não instalado! Instalando agora..."
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      chmod +x kubectl
      sudo mv kubectl /usr/local/bin/
      echo "kubectl instalado com sucesso!"
    else
      echo "kubectl já instalado!"
    fi
  EOT
```

Definição de um recurso do tipo `null_resource` chamado "check_kubectl". 
```terraform
resource "null_resource" "check_kubectl" {
  depends_on = [null_resource.check_docker]
  provisioner "local-exec" {
    command     = local.is_linux ? local.kubectl_cmd_linux : local.kubectl_cmd_windows
    interpreter = local.is_linux ? ["bash", "-c"] : ["PowerShell", "-Command"]
  }
}
```
Na parte depends_on cria uma dependência explícita garantindo que o `kubectl` só será instalado **depois** do `Docker`. O `provisioner "local-exec"` executa comandos localmente na máquina. O parâmetro `command` usa um operador ternário que detecta automaticamente o sistema operacional e seleciona o script apropriado (Linux ou Windows) para verificar e instalar o `kubectl`. Por fim, o `interpreter` define qual **shell** executará o comando: `bash` para Linux ou `PowerShell` para Windows, garantindo compatibilidade multiplataforma.

#### `modules/gppu/`
Todos os módulos terão a mesma estrutura onde eu vou criar um script bash e depois eu chamo ele através do resource.

Neste script é verificado se já foi instalado os drivers da **NVIDIA**, caso nçao teha sido instalado ele instala 
```terraform
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
```

E por fim aqui utilizamos o resource para chamar esse script criado anteriormente.
```terraform
resource "null_resource" "check_nvidia" {
  provisioner "local-exec" {
    command     = local.is_linux ? local.nvidia_cmd_linux : local.nvidia_cmd_windows
    interpreter = local.is_linux ? ["bash", "-c"] : ["PowerShell", "-Command"]
    on_failure  = continue
  }
}
```

#### `modules/cluster/`
Neste módulo é feito a criação do Cluster utilizando o Kind e pra isso precisamos do arquivo `.yaml`.

Criação do cluster
```terraform
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
```
A maior diferença neste arquivo é que utilizamos uma variável que armazena o arquivo de configuração do cluster `.yaml`

Arquivo de variáveis
```terraform
variable "kubeflow" {
  description = "kubeflow"
  type        = string
  default     = "kubeflow-local"
}
```
Utilização do resource para chamar o script 
```terraform
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
```
Desta vez é tulizado **dois** provisioners um faz a criação do cluster e o último destroi o cluster quando o usuário rodar o comando `Terraform destroy`.

#### `modules/kubeflow/`
...
