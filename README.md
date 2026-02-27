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
...
