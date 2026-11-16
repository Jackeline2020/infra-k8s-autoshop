# Infraestrutura como Código (Terraform)

Três projetos Terraform independentes:

| Pasta | O que cria | Quando usar |
|---|---|---|
| `infra/aws/` | Cluster EKS, filas SQS da Saga, roles IAM dos serviços e do GitHub Actions | Produção (AWS) |
| `infra/local/` | Cluster kind com Postgres e o app | Testes na máquina, sem custo |
| `infra/ci/` | Igual ao `local/`, dentro do runner do GitHub Actions | Homologação da `develop` |

Os bancos de dados dos serviços ficam no repositório
[`infra-db-autoshop`](https://github.com/Jackeline2020/infra-db-autoshop),
uma stack por banco.

## `infra/aws/`

| Arquivo | Recursos |
|---|---|
| `network.tf` | Consulta da VPC e das subnets padrão da conta (filtrando as zonas aceitas pelo EKS) |
| `eks.tf` | Cluster `autoshop-eks` (Kubernetes 1.36), node group gerenciado de 3 `t3.small`, IRSA habilitado, acesso de administrador para a role do GitHub Actions |
| `messaging.tf` | Filas `execution-commands`, `billing-commands` e `os-events`, cada uma com DLQ (`maxReceiveCount` 5, retenção de 14 dias) |
| `irsa.tf` | Uma role por serviço (`autoshop-api-irsa`, `autoshop-execution-irsa`, `autoshop-billing-irsa`), assumida pela service account do pod, com acesso só às filas do serviço; a do Execution também acessa as tabelas DynamoDB `autoshop-*` |
| `github-oidc.tf` | Provedor OIDC do GitHub e a role `autoshop-github-actions`, que só pode ser assumida a partir da `main` dos repositórios listados em `deploy_repositories` |
| `variables.tf` | Região, nome e versão do cluster, tipo e quantidade de nodes, repositórios autorizados a fazer deploy |
| `outputs.tf` | Endpoint do cluster, security group dos nodes, ARNs das roles e URLs das filas |

### Por que IRSA

Cada pod assume uma role IAM pela própria service account do Kubernetes,
com credenciais temporárias. Nenhuma chave da AWS fica em imagem,
ConfigMap ou Secret, e cada serviço só enxerga os próprios recursos: o
Billing não consegue ler a fila do Execution, por exemplo.

### Aplicar

```bash
cd infra/aws
terraform init
terraform plan -out=plano
terraform apply plano
aws eks update-kubeconfig --region us-east-1 --name autoshop-eks
```

Na sequência: stacks do `infra-db-autoshop` (com o
`eks_node_security_group_id`), secrets nos repositórios dos serviços e
merge `develop → main` em cada um.

### Destruir

1. `kubectl delete namespace autoshop` (remove os Load Balancers, que não
   estão no estado do Terraform)
2. `terraform destroy` nas stacks do `infra-db-autoshop`
3. `terraform destroy` em `infra/aws`

## `infra/local/` e `infra/ci/`

Cluster kind + namespace + Postgres dentro do cluster + Job de migration +
metrics-server (só no local) + os manifestos do app, lidos do
`app-autoshop` (pasta irmã no local; API do GitHub no CI).

```bash
cd infra/local
terraform init
terraform apply -target="kind_cluster.autoshop"
docker build -t autoshop-api:latest ../../../app-autoshop
kind load docker-image autoshop-api:latest --name autoshop-local
terraform apply
curl http://localhost:30080/health
```

Problemas comuns:

- **"field is immutable" no job de migration**: apagar o job
  (`kubectl delete job db-migrate -n autoshop`) e aplicar de novo.
- **`ImagePullBackOff`**: refazer o `docker build` e o `kind load`, depois
  `kubectl rollout restart deployment/autoshop-api -n autoshop`.

## Considerações de produção

- **State:** local. Uma equipe usaria state remoto (S3 com lock), o que
  também permitiria aplicar a infra pelo pipeline.
- **Rede:** VPC padrão da conta. Uma produção real usaria uma VPC dedicada,
  com subnets privadas para os nodes e os bancos.
- **Exposição:** os serviços usam Load Balancers próprios. Uma produção
  real usaria um Ingress ou um API Gateway na frente, com autorização.
