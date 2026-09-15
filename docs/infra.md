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
- **`aws/`** — cluster EKS e RDS PostgreSQL reais na AWS. O job
  `deploy-aws` está habilitado (`AWS_DEPLOY_ENABLED=true`) e roda a cada
  push na `main`.

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

A cada push na `main`, o job `deploy-aws` assume a IAM Role compartilhada
via OIDC (sem access key estática no GitHub) e aplica o cluster e os
manifestos da aplicação:

1. `terraform apply` provisiona o cluster EKS (nodes `t3.micro`,
   elegíveis ao Free Tier) e as roles de IAM/OIDC.
2. O job injeta os valores reais em `k8s/overlays/aws` a partir dos
   secrets do repositório no GitHub (`DB_HOST`, `IRSA_ROLE_ARN`,
   `JWT_SECRET`, `DB_PASSWORD`, `NEW_RELIC_LICENSE_KEY`), substituindo os
   placeholders do `secret.yaml`/`configmap.yaml` — nenhum segredo fica em
   texto plano versionado no repositório.
3. `kubectl apply -k k8s/overlays/aws` aplica os manifestos no cluster
   real.

Secrets necessários no repositório: `AWS_ROLE_ARN`, `DB_HOST`,
`IRSA_ROLE_ARN`, `JWT_SECRET`, `DB_PASSWORD`, `NEW_RELIC_LICENSE_KEY`.

## Considerações de produção

- **Credenciais da aplicação**: IRSA já implementado — o pod no EKS não
  usa nenhuma chave AWS estática.
- **Rede**: usa a VPC default da conta. Uma produção real usaria uma VPC
  dedicada, com sub-redes públicas/privadas segregadas.
- **State**: gerenciado localmente. Uma equipe com múltiplos
  colaboradores usaria state remoto (ex: S3 + lock no DynamoDB).
