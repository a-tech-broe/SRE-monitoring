# ADR-002: Use Kustomize overlays for environment-specific Kubernetes config

**Status:** Accepted  
**Date:** 2026-05-17

## Context

We deploy the same monitoring stack to two environments (dev and prod)
with different resource sizes, IRSA role ARNs, and replica counts. We need a
way to manage these differences without duplicating manifests.

## Decision

Use **Kustomize base + overlays** pattern.

- `kubernetes/base/` — environment-agnostic manifests
- `kubernetes/overlays/{env}/` — environment-specific patches (IRSA ARNs, resource overrides)

## Rationale

- Kustomize is built into `kubectl` (no extra binary).
- The base/overlay pattern makes diffs reviewable — a PR to `overlays/prod/` is
  clearly scoped to production, reducing review risk.
- Strategic merge patches let us override individual fields without copying the
  full manifest.
- Simpler than Helm for infrastructure-layer manifests (no templating needed for
  most changes).

## Alternatives considered

| Option | Rejected reason |
|--------|----------------|
| Helm values per env | Adds Helm release state management; overkill for infra manifests |
| Separate manifests per env | Duplication; drift is invisible in code review |
| Jsonnet / Tanka | Additional learning curve; niche outside Grafana Labs |

## Consequences

- Engineers must understand Kustomize patch semantics.
- Helm charts (kube-prometheus-stack, Loki) are still used for the application
  layer; Kustomize manages the surrounding namespaces, ServiceAccounts, and
  CRDs.
- `kubectl diff -k` gives a clean before/after view before every apply.
