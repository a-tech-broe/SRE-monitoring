#!/usr/bin/env bash
set -euo pipefail

# Installs all CLI tools required to work on this repo.
# Idempotent — safe to run multiple times.

TERRAFORM_VERSION="1.8.5"
KUBECTL_VERSION="1.30.0"
HELM_VERSION="3.15.2"
TFLINT_VERSION="0.51.1"
CHECKOV_VERSION="3.2.103"

log() { echo "[bootstrap] $*"; }

command_exists() { command -v "$1" &>/dev/null; }

install_terraform() {
  if command_exists terraform && terraform version | grep -q "$TERRAFORM_VERSION"; then
    log "terraform $TERRAFORM_VERSION already installed"
    return
  fi
  log "Installing Terraform $TERRAFORM_VERSION..."
  local os arch zip
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
  zip="terraform_${TERRAFORM_VERSION}_${os}_${arch}.zip"
  curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/${zip}" -o /tmp/terraform.zip
  unzip -o /tmp/terraform.zip -d /usr/local/bin
  rm /tmp/terraform.zip
  log "terraform installed: $(terraform version | head -1)"
}

install_kubectl() {
  if command_exists kubectl && kubectl version --client | grep -q "$KUBECTL_VERSION"; then
    log "kubectl $KUBECTL_VERSION already installed"
    return
  fi
  log "Installing kubectl $KUBECTL_VERSION..."
  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
  curl -fsSL "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/${os}/${arch}/kubectl" -o /usr/local/bin/kubectl
  chmod +x /usr/local/bin/kubectl
  log "kubectl installed: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
}

install_helm() {
  if command_exists helm && helm version --short | grep -q "$HELM_VERSION"; then
    log "helm $HELM_VERSION already installed"
    return
  fi
  log "Installing Helm $HELM_VERSION..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | \
    DESIRED_VERSION="v${HELM_VERSION}" bash
  log "helm installed: $(helm version --short)"
}

install_tflint() {
  if command_exists tflint; then
    log "tflint already installed"
    return
  fi
  log "Installing tflint $TFLINT_VERSION..."
  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
  curl -fsSL "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_${os}_${arch}.zip" \
    -o /tmp/tflint.zip
  unzip -o /tmp/tflint.zip -d /usr/local/bin
  rm /tmp/tflint.zip
  log "tflint installed: $(tflint --version)"
}

install_checkov() {
  if command_exists checkov; then
    log "checkov already installed"
    return
  fi
  log "Installing checkov $CHECKOV_VERSION..."
  pip3 install --quiet "checkov==${CHECKOV_VERSION}"
  log "checkov installed: $(checkov --version)"
}

install_pre_commit() {
  if command_exists pre-commit; then
    log "pre-commit already installed"
    return
  fi
  log "Installing pre-commit..."
  pip3 install --quiet pre-commit
  log "pre-commit installed: $(pre-commit --version)"
}

install_terraform
install_kubectl
install_helm
install_tflint
install_checkov
install_pre_commit

log "Installing pre-commit hooks..."
pre-commit install

log "Bootstrap complete. Run 'make help' to see available targets."
