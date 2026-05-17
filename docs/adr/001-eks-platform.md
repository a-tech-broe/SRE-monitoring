# ADR-001: Use Amazon EKS as the container platform

**Status:** Accepted  
**Date:** 2026-05-17

## Context

We need a container platform to run the centralized monitoring stack
(Prometheus, Grafana, Loki, Alertmanager). The platform must integrate with
AWS-native services and support auto-scaling.

## Decision

Use **Amazon EKS** (managed Kubernetes).

## Rationale

- All 6 application repos already run on EKS; using the same platform minimizes
  operational context-switching.
- The Prometheus Operator / kube-prometheus-stack Helm chart is the de-facto
  standard for Kubernetes-native monitoring.
- EKS integrates natively with IRSA, ALB Controller, and EBS CSI — no
  third-party auth solutions needed.
- Managed control plane reduces operational overhead vs. self-managed k8s.

## Alternatives considered

| Option | Rejected reason |
|--------|----------------|
| ECS Fargate | No native Prometheus Operator support; harder to run stateful sets |
| EC2 (bare) | Full k8s operational burden; no managed node patching |
| Amazon Managed Prometheus only (no EKS) | Can't run Loki, Alertmanager, or exporters without a compute layer |

## Consequences

- Teams need EKS familiarity (kubectl, Helm, Kustomize).
- Node group sizing must accommodate Prometheus TSDB memory requirements.
- The private API endpoint means VPN/bastion access is required for `kubectl` locally.
