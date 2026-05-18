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

### AWS Authentication (OIDC — no static keys)

| Secret name | Description |
|-------------|-------------|
| `AWS_ROLE_DEV` | IAM role ARN for OIDC auth in dev account |
| `AWS_ROLE_PROD` | IAM role ARN for OIDC auth in prod account |

These roles must have a trust policy allowing `token.actions.githubusercontent.com` to assume them. Example:

```json
{
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
      "token.actions.githubusercontent.com:sub": "repo:your-org/SRE-monitoring:ref:refs/heads/main"
    }
  }
}
```

### AWS Account IDs (injected as TF_VAR_aws_account_id)

| Secret name | Description |
|-------------|-------------|
| `AWS_ACCOUNT_ID_DEV` | 12-digit AWS account ID for dev |
| `AWS_ACCOUNT_ID_PROD` | 12-digit AWS account ID for prod |

These are passed to Terraform as `TF_VAR_aws_account_id` — they never appear in committed files.

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
