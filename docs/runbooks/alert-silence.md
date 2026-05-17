# Runbook: Silencing an Alert

Use this when you need to suppress a known-noisy or expected alert during
maintenance, deployments, or investigations.

## Via Alertmanager UI

1. Open the Alertmanager UI (get URL: `kubectl get svc -n monitoring | grep alertmanager`)
2. Click **Silences → New Silence**
3. Set matchers to target only the alert you want to suppress, e.g.:
   - `alertname = PodCrashLooping`
   - `namespace = payment-service`
4. Set an expiry — never silence indefinitely.
5. Add a comment with your ticket/incident number.

## Via amtool CLI

```bash
# Silence a specific alert for 2 hours
amtool silence add \
  --alertmanager.url=http://localhost:9093 \
  --comment="Maintenance window TICKET-1234" \
  --duration=2h \
  alertname=PodCrashLooping namespace=payment-service

# List active silences
amtool silence query --alertmanager.url=http://localhost:9093

# Expire a silence early
amtool silence expire <silence-id> --alertmanager.url=http://localhost:9093
```

## Port-forwarding Alertmanager locally

```bash
kubectl port-forward svc/alertmanager-operated 9093:9093 -n monitoring
```

## Important guidelines

- Always set an expiry. A silence without an expiry is a hidden outage waiting to happen.
- Include a ticket number in the comment.
- After the maintenance window, verify the alert would have fired correctly
  by checking the expression in Prometheus.
