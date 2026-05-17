# SRE-monitoring — Observability Platform

Centralized monitoring stack with auto service discovery for all application repos.

---

## Overview

This repo owns 100% of the observability infrastructure: metrics, logs, alerting, dashboards, and the AWS resources that power them. Application repos register themselves automatically — no changes here required.

```
GitHub
│
├── app-repo-1  ──┐
├── app-repo-2  ──┤
├── app-repo-3  ──┼──► label: prometheus.io/scrape: "true" → auto-discovered
├── app-repo-4  ──┤
├── app-repo-5  ──┤
└── app-repo-6  ──┘

└── SRE-monitoring (this repo)
      ├── terraform/          IaC — EKS, AMP, Grafana, networking, IAM
      ├── kubernetes/         Manifests — Prometheus, Loki, Alertmanager, ingress
      ├── dashboards/         Grafana dashboard JSON
      ├── alerts/             PrometheusRule CRDs
      ├── scripts/            Operator tooling
      ├── docs/               Architecture, runbooks, ADRs
      └── .github/workflows/  CI/CD pipelines
```

---

## Stack

| Component | Technology |
|-----------|-----------|
| Container Platform | Amazon EKS |
| Metrics | Prometheus Operator + kube-prometheus-stack |
| Long-term Metrics | Amazon Managed Prometheus (AMP) |
| Dashboards | Amazon Managed Grafana |
| Logs | Loki (distributed, S3-backed) |
| Alerting | Alertmanager |
| Auto Discovery | Kubernetes ServiceMonitor |
| IaC | Terraform |
| CI/CD | GitHub Actions |
| Ingress | AWS Load Balancer Controller |
| Auth | IAM Roles for Service Accounts (IRSA) |

---

## Repository Structure

```
SRE-monitoring/
│
├── terraform/
│   ├── modules/
│   │   ├── eks/              EKS cluster, node groups, OIDC, KMS encryption
│   │   ├── amp/              Amazon Managed Prometheus workspace
│   │   ├── grafana/          Amazon Managed Grafana workspace
│   │   ├── networking/       VPC, subnets, NAT gateways, flow logs
│   │   └── iam/              IRSA roles for Prometheus, Grafana, Loki, ALB
│   └── environments/
│       ├── dev/
│       ├── staging/
│       └── prod/
│
├── kubernetes/
│   ├── base/
│   │   ├── prometheus/       Namespace, ServiceMonitor, Helm values
│   │   ├── loki/             Namespace, Helm values
│   │   ├── alertmanager/     Routing config
│   │   └── ingress/          ALB Controller ServiceAccount
│   └── overlays/
│       ├── dev/              IRSA patches for dev account
│       ├── staging/          IRSA patches for staging account
│       └── prod/             IRSA patches + resource overrides for prod
│
├── dashboards/
│   ├── kubernetes/           Cluster overview
│   ├── application/          Golden signals (Traffic, Errors, Latency, Saturation)
│   └── infrastructure/       EKS node-level metrics
│
├── alerts/
│   ├── kubernetes/           Pod and node alert rules
│   ├── application/          SLO burn-rate, error rate, latency
│   └── infrastructure/       AWS/EKS health, storage
│
├── scripts/
│   ├── bootstrap.sh          Install all required CLI tools
│   ├── validate.sh           Run all checks locally before pushing
│   └── sync-dashboards.sh    Push dashboard JSON to Grafana via API
│
├── docs/
│   ├── architecture.md
│   ├── onboarding.md
│   ├── runbooks/
│   └── adr/
│
├── .github/workflows/
│   ├── terraform-plan.yml    PR: plan all 3 envs, post output as comment
│   ├── terraform-apply.yml   Push to main: apply dev → staging → prod
│   ├── deploy-monitoring.yml Push to main: kubectl apply + dashboard sync
│   ├── lint.yml              fmt, tflint, yamllint, shellcheck, promtool
│   └── security-scan.yml     Checkov, Gitleaks, Trivy → GitHub Security tab
│
├── Makefile                  Common targets (plan, apply, deploy, lint, …)
├── .pre-commit-config.yaml
├── .tflint.hcl
└── .yamllint.yaml
```

---

## Environments

| Env | AWS Account | EKS Node Type | HA |
|-----|-------------|---------------|----|
| dev | 111111111111 | m6i.xlarge ×2 | Single NAT |
| staging | 222222222222 | m6i.2xlarge ×3 | Multi-AZ |
| prod | 333333333333 | m6i.4xlarge ×3 + Spot pool | Multi-AZ |

> Replace account IDs in `terraform/environments/*/terraform.tfvars` with your real values.

---

## Getting Started

### 1. Bootstrap your workstation

```bash
make bootstrap
```

Installs: terraform, kubectl, helm, tflint, checkov, pre-commit.

### 2. Deploy infrastructure

```bash
make init ENV=dev
make plan ENV=dev
make apply ENV=dev
```

### 3. Deploy the monitoring stack

```bash
aws eks update-kubeconfig --name observability-dev --region us-east-1
make deploy-dev
```

### 4. Validate everything locally

```bash
./scripts/validate.sh
```

---

## Service Discovery — Registering an Application

Add one label to your application's Kubernetes `Service`:

```yaml
metadata:
  labels:
    prometheus.io/scrape: "true"
```

Prometheus discovers and scrapes the service within ~30 seconds. No changes to this repo needed.

---

## Alerting

Alerts are defined as `PrometheusRule` CRDs under `alerts/`. Routing:

| Severity | Receiver |
|----------|----------|
| `critical` | PagerDuty |
| `warning` | Slack `#alerts-warning` |

SLO alerts use the multi-window burn-rate method (Google SRE book, Ch. 5) targeting 99.9% availability.

Validate rules before pushing:
```bash
make validate-alerts
```

---

## Dashboards

Dashboards live as JSON under `dashboards/` and are synced to Grafana on every merge to `main`. To add a dashboard:

1. Export JSON from Grafana → **Share → Export**
2. Save under `dashboards/<category>/<name>.json`
3. Open a PR — it syncs automatically on merge

---

## Security

- EKS API endpoint is **private-only** across all environments
- All pod identities use **IRSA** — no static IAM keys
- S3 buckets: private, SSE-S3 encrypted, public access blocked
- EKS secrets encrypted with a per-cluster **KMS** key
- **VPC Flow Logs** enabled on all VPCs
- Every PR runs **Checkov + Trivy + Gitleaks**; results posted to GitHub Security tab

---

## Key Commands

```bash
make help               # full target list

# Terraform
make plan ENV=dev       # plan dev
make apply ENV=dev      # apply dev

# Kubernetes
make kube-diff ENV=dev  # diff manifests against live cluster
make deploy-dev         # apply dev manifests

# Quality
make lint               # terraform fmt + tflint
make validate-alerts    # promtool check rules on all alert files
make pre-commit         # full pre-commit suite
./scripts/validate.sh   # all checks in one shot
```

---

## Docs

- [Architecture](docs/architecture.md)
- [Onboarding](docs/onboarding.md)
- [Runbook: High Memory](docs/runbooks/high-memory.md)
- [Runbook: Alert Silence](docs/runbooks/alert-silence.md)
- [ADR-001: EKS Platform](docs/adr/001-eks-platform.md)
- [ADR-002: Kustomize Overlays](docs/adr/002-kustomize-overlays.md)
