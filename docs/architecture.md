# Architecture

## Overview

The observability platform runs on Amazon EKS and uses AWS-managed services for
long-term storage and auth. Application repos register themselves automatically
via Kubernetes ServiceMonitor discovery — no changes to this repo required.

```
┌───────────────────────────────────────────────────────────────┐
│                         AWS Account                           │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │                     Amazon EKS                          │  │
│  │                                                         │  │
│  │  monitoring ns        logging ns     kube-system ns     │  │
│  │  ┌──────────────┐   ┌───────────┐   ┌───────────────┐  │  │
│  │  │  Prometheus  │   │   Loki    │   │ ALB Controller│  │  │
│  │  │  Operator    │   │ (dist.)   │   │               │  │  │
│  │  │  Alertmanager│   └─────┬─────┘   └───────┬───────┘  │  │
│  │  └──────┬───────┘         │                 │          │  │
│  │         │                 │                 │          │  │
│  └─────────┼─────────────────┼─────────────────┼──────────┘  │
│            │ remote_write    │ chunks          │ ingress      │
│            ▼                 ▼                 ▼              │
│  ┌─────────────────┐  ┌──────────┐   ┌────────────────────┐  │
│  │ Amazon Managed  │  │  S3      │   │ AWS Load Balancer   │  │
│  │ Prometheus (AMP)│  │  Bucket  │   │                     │  │
│  └────────┬────────┘  └──────────┘   └────────────────────┘  │
│           │ query                                             │
│           ▼                                                   │
│  ┌────────────────────┐                                       │
│  │ Amazon Managed     │                                       │
│  │ Grafana            │◄── AWS SSO / SAML                     │
│  └────────────────────┘                                       │
│                                                               │
│  IAM / IRSA: each pod assumes a least-privilege role          │
└───────────────────────────────────────────────────────────────┘
```

## Service Discovery

ServiceMonitors with `namespaceSelector: any: true` scrape any service that
carries the label `prometheus.io/scrape: "true"`. Application repos only need
to add that label to their `Service` manifest — no changes to this repo needed.

## Data Flows

| Data | Source | Storage | Retention |
|------|--------|---------|-----------|
| Metrics | Prometheus scrape | AMP (remote_write) | 13 months |
| Metrics (recent) | Prometheus TSDB | EBS PVC | 2h (prod: 4h) |
| Logs | Promtail → Loki | S3 | 30 days |
| Traces | AWS X-Ray (via Grafana) | X-Ray | 30 days |

## Environments

| Env | Account | EKS Instance | Single NAT |
|-----|---------|-------------|------------|
| dev | 111111111111 | m6i.xlarge ×2 | yes |
| prod | 333333333333 | m6i.4xlarge ×3 + spot | no |

## Security

- EKS API endpoint is **private only** in all environments.
- All pods use **IRSA** (IAM Roles for Service Accounts) — no static keys.
- S3 buckets are private with SSE-S3 encryption.
- EKS secrets are envelope-encrypted with a per-cluster KMS key.
- VPC Flow Logs are enabled on all VPCs.
- Checkov, Trivy, and Gitleaks run on every PR.
