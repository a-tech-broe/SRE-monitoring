.DEFAULT_GOAL := help
SHELL         := /bin/bash
ENV           ?= dev

TERRAFORM_DIR := terraform/environments/$(ENV)
KUBE_DIR      := kubernetes/overlays/$(ENV)

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-28s\033[0m %s\n", $$1, $$2}'

# ── Terraform ──────────────────────────────────────────────────────────────────

.PHONY: init
init: ## Init Terraform for ENV (default: dev)
	cd $(TERRAFORM_DIR) && terraform init -upgrade

.PHONY: fmt
fmt: ## Format all Terraform files
	terraform fmt -recursive terraform/

.PHONY: validate
validate: ## Validate Terraform for ENV
	cd $(TERRAFORM_DIR) && terraform validate

.PHONY: lint
lint: ## Run tflint across all modules
	tflint --recursive terraform/

.PHONY: plan
plan: ## Plan Terraform for ENV
	cd $(TERRAFORM_DIR) && terraform plan -out=tfplan

.PHONY: apply
apply: ## Apply saved plan for ENV
	cd $(TERRAFORM_DIR) && terraform apply tfplan

.PHONY: destroy
destroy: ## Destroy ENV infra (requires confirmation)
	cd $(TERRAFORM_DIR) && terraform destroy

.PHONY: plan-dev
plan-dev: ## Plan dev environment
	$(MAKE) plan ENV=dev

.PHONY: plan-prod
plan-prod: ## Plan prod environment
	$(MAKE) plan ENV=prod

.PHONY: apply-dev
apply-dev: ## Apply dev environment
	$(MAKE) apply ENV=dev

.PHONY: apply-prod
apply-prod: ## Apply prod environment (use CI/CD in practice)
	$(MAKE) apply ENV=prod

# ── Kubernetes ─────────────────────────────────────────────────────────────────

.PHONY: kube-diff
kube-diff: ## Diff kustomize manifests for ENV against cluster
	kubectl diff -k $(KUBE_DIR)

.PHONY: kube-apply
kube-apply: ## Apply kustomize manifests for ENV
	kubectl apply -k $(KUBE_DIR)

.PHONY: deploy-dev
deploy-dev: ## Deploy monitoring stack to dev
	$(MAKE) kube-apply ENV=dev

.PHONY: deploy-prod
deploy-prod: ## Deploy monitoring stack to prod (use CI/CD in practice)
	$(MAKE) kube-apply ENV=prod

# ── Dashboards ─────────────────────────────────────────────────────────────────

.PHONY: sync-dashboards
sync-dashboards: ## Push all dashboard JSON to Grafana via API
	./scripts/sync-dashboards.sh $(ENV)

# ── Quality gates ──────────────────────────────────────────────────────────────

.PHONY: pre-commit
pre-commit: ## Run all pre-commit hooks
	pre-commit run --all-files

.PHONY: security-scan
security-scan: ## Run checkov against Terraform
	checkov -d terraform/ --framework terraform

.PHONY: validate-alerts
validate-alerts: ## Validate PrometheusRule YAML with promtool
	find alerts/ -name '*.yaml' | xargs -I{} promtool check rules {}

.PHONY: bootstrap
bootstrap: ## Bootstrap a fresh workstation / CI agent
	./scripts/bootstrap.sh

# ── Cleanup / Teardown ─────────────────────────────────────────────────────────

.PHONY: cleanup
cleanup: ## Teardown all phases for ENV (default: dev) — prompts for confirmation
	./scripts/cleanup.sh --env $(ENV)

.PHONY: cleanup-dev
cleanup-dev: ## Teardown dev environment (all phases)
	./scripts/cleanup.sh --env dev

.PHONY: cleanup-prod
cleanup-prod: ## Teardown prod environment (all phases)
	./scripts/cleanup.sh --env prod

.PHONY: cleanup-all
cleanup-all: ## Teardown ALL environments + bootstrap resources
	./scripts/cleanup.sh --env all

.PHONY: cleanup-k8s
cleanup-k8s: ## Teardown Kubernetes workloads only for ENV (no Terraform)
	./scripts/cleanup.sh --env $(ENV) --phase k8s

.PHONY: cleanup-tf
cleanup-tf: ## Run terraform destroy only for ENV (K8s must be torn down first)
	./scripts/cleanup.sh --env $(ENV) --phase terraform

.PHONY: cleanup-bootstrap
cleanup-bootstrap: ## Destroy bootstrap OIDC + CI IAM roles (cuts GHA AWS access)
	./scripts/cleanup.sh --env dev --phase bootstrap

.PHONY: cleanup-dry-run
cleanup-dry-run: ## Preview teardown for ENV without making any changes
	./scripts/cleanup.sh --env $(ENV) --dry-run
