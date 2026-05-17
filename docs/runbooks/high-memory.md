# Runbook: High Memory Usage (Pod / Node)

**Triggered by:** `PodHighMemoryUsage`, `NodeHighMemory`

## Immediate triage (< 5 min)

1. Identify the affected resource:
   ```bash
   kubectl top pods -A --sort-by memory | head -20
   kubectl top nodes
   ```

2. Check if the container is close to its limit:
   ```bash
   kubectl describe pod <pod> -n <namespace> | grep -A5 Limits
   ```

3. Check recent memory trend in Grafana → **Golden Signals** dashboard →
   filter by the affected namespace/job.

## If memory is legitimately growing (load spike)

- Check if HPA is scaling the deployment: `kubectl get hpa -n <namespace>`
- If HPA is maxed out, check if node autoscaler is adding nodes:
  `kubectl get nodes -w`
- If nodes are not scaling, check the ASG in AWS Console.

## If memory looks like a leak

1. Capture a heap dump if the application supports it (language-specific).
2. Restart the pod as a short-term fix: `kubectl rollout restart deployment/<name> -n <namespace>`
3. File a ticket with the app team and attach Grafana screenshot + pod logs.

## If Prometheus itself is the culprit

1. Check cardinality: open Prometheus UI → **Status → TSDB Status** → top series by label.
2. High cardinality is usually caused by a label with unbounded values (e.g., `request_id`).
3. Add a `metric_relabel_configs` drop rule in `kubernetes/base/prometheus/helm-values.yaml`.

## Escalation

- Memory > 95% and pod is OOMKilled repeatedly → page on-call via PagerDuty.
- Node memory > 90% across all nodes → page on-call.
