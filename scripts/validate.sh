#!/usr/bin/env bash
set -euo pipefail

# Runs all local validation checks before pushing.
# Mirrors what CI runs so you catch issues before the PR.

PASS=0
FAIL=0

check() {
  local name="$1"
  shift
  echo -n "  [$name] "
  if "$@" &>/dev/null; then
    echo "PASS"
    ((PASS++))
  else
    echo "FAIL"
    ((FAIL++))
    "$@" || true  # re-run to show output
  fi
}

echo "=== Terraform ==="
for env in dev staging prod; do
  check "fmt:$env"      terraform fmt -check -recursive "terraform/environments/$env"
  check "validate:$env" bash -c "cd terraform/environments/$env && terraform validate"
done

echo ""
echo "=== Alert rules ==="
while IFS= read -r -d '' f; do
  check "promtool:$(basename "$f")" promtool check rules "$f"
done < <(find alerts/ -name '*.yaml' -print0)

echo ""
echo "=== YAML lint ==="
check "yamllint:kubernetes" yamllint -c .yamllint.yaml kubernetes/
check "yamllint:alerts"     yamllint -c .yamllint.yaml alerts/

echo ""
echo "=== Kustomize build ==="
for env in dev staging prod; do
  check "kustomize:$env" kubectl kustomize "kubernetes/overlays/$env"
done

echo ""
echo "=== Shell scripts ==="
check "shellcheck" shellcheck scripts/*.sh

echo ""
if [[ $FAIL -gt 0 ]]; then
  echo "Result: $PASS passed, $FAIL FAILED"
  exit 1
else
  echo "Result: all $PASS checks passed"
fi
