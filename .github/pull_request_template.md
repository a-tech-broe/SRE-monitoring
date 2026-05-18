## Summary
<!-- What does this PR do and why? -->

## Type of change
- [ ] Terraform infrastructure change
- [ ] Kubernetes manifest / Helm values change
- [ ] Alert rule change
- [ ] Dashboard change
- [ ] CI/CD pipeline change
- [ ] Documentation
- [ ] Other

## Environments affected
- [ ] dev
- [ ] prod

## Checklist
- [ ] `make fmt` and `make lint` pass locally
- [ ] `make validate` passes for all affected environments
- [ ] `make validate-alerts` passes if alert rules were changed
- [ ] Terraform plan output reviewed and attached (for infra changes)
- [ ] `kubectl diff` reviewed for Kubernetes changes
- [ ] No secrets or credentials in the diff
- [ ] CODEOWNERS reviewers requested

## Terraform plan output
<!-- Paste `terraform plan` summary here for infra changes -->
```
<paste plan output>
```

## Rollback plan
<!-- How do we revert this if it causes an incident? -->
