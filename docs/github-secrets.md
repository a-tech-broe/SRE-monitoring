# GitHub Secrets & Variables Reference

All sensitive values are stored as **GitHub Secrets** and injected into CI/CD at runtime.
Nothing sensitive is committed to the repository.

---

## How to add a secret

```
GitHub repo → Settings → Secrets and variables → Actions → New repository secret
```

---

## Required Secrets

### AWS Authentication (static IAM user credentials)

| Secret name | Description |
|-------------|-------------|
| `AWS_ACCESS_KEY_ID` | Access key ID for the CI IAM user |
| `AWS_SECRET_ACCESS_KEY` | Secret access key for the CI IAM user |

Both environments share the same AWS account. Create a single dedicated CI IAM user, generate an access key, and store both values as secrets above.

### AWS Account ID (injected as TF_VAR_aws_account_id)

| Secret name | Description |
|-------------|-------------|
| `AWS_ACCOUNT_ID` | 12-digit AWS account ID (shared by dev and prod) |

Passed to Terraform as `TF_VAR_aws_account_id` — never appears in committed files.

### Grafana

| Secret name | Description |
|-------------|-------------|
| `GRAFANA_URL_DEV` | Amazon Managed Grafana workspace URL for dev |
| `GRAFANA_URL_PROD` | Amazon Managed Grafana workspace URL for prod |
| `GRAFANA_SA_TOKEN_DEV` | Grafana service account token for dev (Admin role) |
| `GRAFANA_SA_TOKEN_PROD` | Grafana service account token for prod |

### EKS Cluster Names (non-sensitive, but kept as secrets for flexibility)

| Secret name | Description |
|-------------|-------------|
| `EKS_CLUSTER_DEV` | EKS cluster name in dev (e.g. `observability-dev`) |
| `EKS_CLUSTER_PROD` | EKS cluster name in prod |

---

## Required Variables (non-sensitive)

```
GitHub repo → Settings → Secrets and variables → Actions → Variables tab
```

| Variable name | Example value | Description |
|---------------|---------------|-------------|
| `AWS_REGION` | `us-east-1` | AWS region for all environments |

---

## Alertmanager Secrets (AWS Secrets Manager)

Alertmanager reads these at runtime from mounted secret files — they are never in GitHub.

| AWS Secret name | Description |
|-----------------|-------------|
| `observability/{env}/pagerduty-routing-key` | PagerDuty Events v2 routing key |
| `observability/{env}/slack-webhook-url` | Slack incoming webhook URL |

Create them with:

```bash
aws secretsmanager create-secret \
  --name "observability/dev/pagerduty-routing-key" \
  --secret-string "YOUR_KEY_HERE" \
  --region us-east-1
```

---

## What is NOT stored in GitHub Secrets

| Item | Where it lives |
|------|---------------|
| AWS access keys | Nowhere — OIDC is used instead |
| Terraform state | S3 backend (encrypted) |
| Loki S3 data | S3 (SSE-S3 encrypted) |
| kubeconfig | Generated at runtime via `aws eks update-kubeconfig` |
