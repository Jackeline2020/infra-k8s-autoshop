# Infraestrutura como Código (Terraform)

Os manifestos Kubernetes ficam em `k8s/base` (comum a todos os ambientes)
e `k8s/overlays/local` / `k8s/overlays/aws` (o que muda entre eles). O
Terraform aplica esses manifestos como resources reais (`kubectl_manifest`),
não via `kubectl apply` direto.

Três pastas, cada uma um projeto Terraform independente:

- **`local/`** — cluster Kubernetes local (kind), sem custo, para testes.
- **`ci/`** — mesma estrutura do `local/`, mas roda dentro do runner do
  GitHub Actions a cada push: sobe um cluster efêmero, aplica tudo com a
  imagem recém publicada, e testa. É o que o pipeline de CI/CD usa.
- **`aws/`** — cluster EKS e RDS PostgreSQL reais na AWS. Gera custo. Não
  faz parte do escopo obrigatório desta entrega — o job `deploy-aws` fica
  desligado por padrão (variável `AWS_DEPLOY_ENABLED`).

## O que cada pasta cria

### `local/`

Cluster kind + namespace + Postgres (dentro do cluster) + Job que aplica
a migration do schema (`migrations/000001_init_schema.up.sql`) +
metrics-server via Helm (necessário pro HPA) + os manifestos da aplicação
(config, secret, deployment, service, hpa).

O cluster kind não enxerga imagens Docker buildadas fora dele — por isso a
imagem da API precisa ser carregada manualmente antes do deploy (ver
"Como aplicar").

### `ci/`

Estrutura parecida com a do `local/`, com diferenças: usa a imagem
publicada no GHCR nesta execução (em vez de uma tag fixa), cria um
`imagePullSecret` a partir do `GITHUB_TOKEN` do próprio workflow — o
cluster efêmero não tem a imagem em cache local — e não instala o
metrics-server (evita competir por CPU/memória no runner).

### `aws/`

Cria um cluster EKS gerenciado, uma instância RDS PostgreSQL real (numa
subnet privada, só acessível a partir dos nodes do EKS) com a credencial
guardada no Secrets Manager, e a configuração de acesso necessária
(autenticação do GitHub Actions via OIDC, sem chave fixa, e uma IAM Role
dedicada ao pod da API via IRSA — que agora só tem permissão de
`secretsmanager:GetSecretValue` na credencial do banco, sem acesso direto
a nenhum serviço de dados).

## Como aplicar

### Local

Pré-requisitos: Terraform >= 1.5, Docker, CLI `kind` (`winget install Kubernetes.kind`
no Windows, ou ver [kind.sigs.k8s.io](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)).

```bash
cd infra/local
terraform init
terraform apply -target="kind_cluster.autoshop"   # cria só o cluster primeiro

docker build -t autoshop-api:latest ../..
kind load docker-image autoshop-api:latest --name autoshop-local

terraform apply                                  # aplica o restante

# esse apply não fica esperando o Deployment ficar 100% disponível
kubeconfig=$(terraform output -raw kubeconfig_path)
kubectl --kubeconfig "$kubeconfig" rollout status deployment/autoshop-api -n autoshop --timeout=300s

curl http://localhost:30080/health
```

Pra encerrar: `terraform destroy`.

Se um `terraform apply` for repetido depois que o job `db-migrate` já
rodou, o Kubernetes pode recusar o patch com "field is immutable" (o
`spec.template` de um Job não pode ser alterado). Nesse caso, apaga o job e
aplica de novo:

```bash
kubectl --kubeconfig $(terraform output -raw kubeconfig_path) delete job db-migrate -n autoshop
terraform apply
```

Se os pods da API ficarem em `ImagePullBackOff`/`ErrImagePull`, refaz o build/load e reinicia o rollout

```bash
docker build -t autoshop-api:latest ../..
kind load docker-image autoshop-api:latest --name autoshop-local
kubectl --kubeconfig $(terraform output -raw kubeconfig_path) rollout restart deployment/autoshop-api -n autoshop
```

### AWS

Não faz parte do escopo desta entrega — o código existe e está revisado
(via `terraform plan`), mas fica desligado por padrão. Antes de aplicar de
verdade:

1. Troque os valores placeholder de `k8s/overlays/aws/secret.yaml` por
   segredos reais (esse arquivo é aplicado via `kubectl apply -k`, fora do
   Terraform).
2. Depois do primeiro `terraform apply`, copie o valor do output
   `rds_endpoint` para o Secret `DB_HOST` do repositório no GitHub — o job
   `deploy-aws` injeta esse valor em `k8s/overlays/aws/configmap.yaml` do
   mesmo jeito que já faz hoje com `IRSA_ROLE_ARN`.

## Considerações de produção

- **Credenciais da aplicação**: IRSA já implementado — o pod no EKS não
  usa nenhuma chave AWS estática.
- **VPC dedicada**: não implementada (fora do escopo) — usa a VPC default
  da conta.
- **State remoto**: não implementado — o state fica local.
