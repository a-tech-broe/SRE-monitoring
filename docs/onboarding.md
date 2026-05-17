# Onboarding — Getting Started

## Prerequisites

Run the bootstrap script to install all required tools:

```bash
make bootstrap
```

This installs: terraform, kubectl, helm, tflint, checkov, pre-commit.

## AWS Access

You need IAM access to the target account. In CI, GitHub Actions uses OIDC;
locally, configure a profile:

```bash
aws configure --profile observability-dev
export AWS_PROFILE=observability-dev
```

## Making Your First Change

### Terraform change

```bash
make init ENV=dev
make plan ENV=dev        # review the plan output
make apply ENV=dev       # apply it
```

### Kubernetes / manifest change

```bash
# Point kubectl at the right cluster
aws eks update-kubeconfig --name observability-dev --region us-east-1

make kube-diff ENV=dev   # see what would change
make deploy-dev          # apply it
```

### Adding an alert rule

1. Add a `PrometheusRule` manifest under `alerts/<category>/`.
2. Validate it: `make validate-alerts`
3. Open a PR — the lint workflow will run `promtool check rules` automatically.

### Adding a Grafana dashboard

1. Export the dashboard JSON from Grafana (Dashboard → Share → Export JSON).
2. Save it under `dashboards/<category>/<name>.json`.
3. On merge to `main`, the deploy workflow calls `sync-dashboards.sh` automatically.

## Registering an Application Repo

In your application's Kubernetes `Service` manifest, add one label:

```yaml
metadata:
  labels:
    prometheus.io/scrape: "true"
```

Prometheus will discover and scrape the service automatically within ~30 seconds.
No changes to this repo are needed.

## Running All Checks Locally

```bash
make pre-commit          # full pre-commit hook suite
./scripts/validate.sh    # all checks in one script
```

## Key Resources

| Resource | Where |
|----------|-------|
| Architecture diagram | [docs/architecture.md](architecture.md) |
| Alert runbooks | [docs/runbooks/](runbooks/) |
| Architecture decisions | [docs/adr/](adr/) |
| Grafana | See Terraform output `grafana_endpoint` |
