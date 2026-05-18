#!/usr/bin/env bash
# Teardown all resources provisioned by the SRE-monitoring observability platform.
# Phase order (dependency-safe): k8s → s3 → terraform → bootstrap
set -euo pipefail

# ── Colours ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info()   { echo -e "${CYAN}[INFO]${RESET}  $*"; }
warn()   { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
ok()     { echo -e "${GREEN}[OK]${RESET}    $*"; }
err()    { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die()    { err "$*"; exit 1; }
header() {
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}  $*${RESET}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# ── Defaults ───────────────────────────────────────────────────────────────────
ENV=""
PHASE="all"
DRY_RUN=false
SKIP_CONFIRM=false
REGION="us-east-1"
ACCOUNT_ID=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# ── Usage ──────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") --env <dev|prod|all> [OPTIONS]

Destroys all infrastructure provisioned by the SRE-monitoring observability
platform. Phases run in this dependency order:
  k8s       — Helm releases + Kubernetes manifests (must run before terraform)
  s3        — Empty versioned Loki S3 bucket (must run before terraform)
  terraform — terraform destroy for the environment
  bootstrap — GitHub Actions OIDC provider and CI IAM roles (confirm required)

Required:
  --env <dev|prod|all>

Options:
  --phase <phase>       Run only one phase: k8s | s3 | terraform | bootstrap | all
  --region <region>     AWS region (default: us-east-1)
  --dry-run             Print commands without executing them
  --skip-confirm        Skip interactive prompts — for CI/automation use
  -h, --help

Examples:
  $(basename "$0") --env dev
  $(basename "$0") --env prod --dry-run
  $(basename "$0") --env all --skip-confirm
  $(basename "$0") --env dev --phase k8s
  $(basename "$0") --env all --phase bootstrap
EOF
  exit 0
}

# ── Arg parsing ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)          ENV="$2";    shift 2 ;;
    --phase)        PHASE="$2";  shift 2 ;;
    --region)       REGION="$2"; shift 2 ;;
    --dry-run)      DRY_RUN=true;       shift ;;
    --skip-confirm) SKIP_CONFIRM=true;  shift ;;
    -h|--help)      usage ;;
    *) die "Unknown option: $1  (run with --help)" ;;
  esac
done

[[ -z "$ENV" ]]   && die "--env is required (dev | prod | all)"
[[ "$ENV"   =~ ^(dev|prod|all)$ ]]                           || die "--env must be: dev, prod, or all"
[[ "$PHASE" =~ ^(k8s|s3|terraform|bootstrap|all)$ ]]        || die "--phase must be: k8s, s3, terraform, bootstrap, or all"

# ── Pre-flight ─────────────────────────────────────────────────────────────────
preflight() {
  header "Pre-flight checks"

  local required=(aws terraform jq)
  [[ "$PHASE" == "k8s" || "$PHASE" == "all" ]] && required+=(kubectl helm)

  local missing=()
  for cmd in "${required[@]}"; do
    if command -v "$cmd" &>/dev/null; then
      ok "$cmd  →  $(command -v "$cmd")"
    else
      err "missing: $cmd"
      missing+=("$cmd")
    fi
  done
  [[ ${#missing[@]} -gt 0 ]] && die "Install missing tools and retry: ${missing[*]}"

  info "Verifying AWS credentials..."
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) \
    || die "No valid AWS credentials. Configure with: aws configure  or set AWS_* env vars."
  export ACCOUNT_ID
  ok "AWS account: $ACCOUNT_ID  region: $REGION"
}

# ── Confirm gate ───────────────────────────────────────────────────────────────
confirm() {
  local env="$1"
  $SKIP_CONFIRM && { warn "Skipping confirmation (--skip-confirm)"; return 0; }
  echo ""
  echo -e "${RED}${BOLD}┌──────────────────────────────────────────────────────────────────┐${RESET}"
  echo -e "${RED}${BOLD}│  WARNING: Permanent destruction of the $env observability stack   ${RESET}"
  echo -e "${RED}${BOLD}│  All metrics, logs, and dashboards will be lost.                  │${RESET}"
  echo -e "${RED}${BOLD}└──────────────────────────────────────────────────────────────────┘${RESET}"
  echo ""
  printf "Type the environment name to confirm [%s]: " "$env"
  read -r answer
  [[ "$answer" == "$env" ]] || die "Confirmation mismatch — aborting."
}

# ── Phase 1: Kubernetes teardown ───────────────────────────────────────────────
teardown_k8s() {
  local env="$1"
  header "Phase 1 — Kubernetes teardown ($env)"

  if $DRY_RUN; then
    warn "[DRY-RUN] Would run: aws eks update-kubeconfig --name observability-$env"
    warn "[DRY-RUN] Would run: kubectl delete ingress --all-namespaces --all --ignore-not-found"
    warn "[DRY-RUN] Would run: helm uninstall kube-prometheus -n monitoring"
    warn "[DRY-RUN] Would run: helm uninstall loki -n logging"
    warn "[DRY-RUN] Would run: kubectl delete -k $REPO_ROOT/kubernetes/overlays/$env"
    warn "[DRY-RUN] Would run: kubectl delete namespace monitoring logging"
    return 0
  fi

  info "Configuring kubectl for cluster observability-$env ..."
  if ! aws eks update-kubeconfig --name "observability-$env" --region "$REGION" 2>/dev/null; then
    warn "Could not configure kubectl for observability-$env."
    warn "This is expected for prod (private-only API endpoint)."
    warn "Run the k8s phase locally from within the VPC, then re-run with --phase s3"
    return 0
  fi

  # Delete Ingress resources first — this triggers the ALB Controller to delete ALBs.
  # Namespace deletion would also do this, but removing Ingresses first gives the
  # controller time to clean up before we proceed.
  info "Deleting Ingress resources (triggers ALB cleanup via Load Balancer Controller)..."
  kubectl delete ingress --all-namespaces --all --ignore-not-found --timeout=60s 2>/dev/null || true

  info "Waiting up to 120s for ALBs to be released from the VPC subnets..."
  local deadline=$((SECONDS + 120))
  while [[ $SECONDS -lt $deadline ]]; do
    local count
    count=$(aws resourcegroupstaggingapi get-resources \
      --tag-filters "Key=kubernetes.io/cluster/observability-$env,Values=owned" \
      --resource-type-filters "elasticloadbalancing:loadbalancer" \
      --region "$REGION" \
      --query 'ResourceTagMappingList | length(@)' \
      --output text 2>/dev/null || echo "0")
    if [[ "$count" == "0" || "$count" == "None" ]]; then
      ok "No ALBs remain for cluster observability-$env."
      break
    fi
    info "  $count ALB(s) still being deleted by the controller... (${SECONDS}s elapsed)"
    sleep 10
  done

  info "Uninstalling Helm release: kube-prometheus ..."
  helm uninstall kube-prometheus --namespace monitoring 2>/dev/null || true

  info "Uninstalling Helm release: loki ..."
  helm uninstall loki --namespace logging 2>/dev/null || true

  info "Deleting remaining Kustomize manifests..."
  kubectl delete -k "$REPO_ROOT/kubernetes/overlays/$env" --ignore-not-found --timeout=120s 2>/dev/null || true

  info "Deleting namespace monitoring (triggers PVC/PersistentVolume cleanup)..."
  kubectl delete namespace monitoring --ignore-not-found --timeout=180s 2>/dev/null || true

  info "Deleting namespace logging..."
  kubectl delete namespace logging --ignore-not-found --timeout=180s 2>/dev/null || true

  ok "Kubernetes teardown complete for $env."
}

# ── Phase 2: Empty versioned S3 Loki bucket ───────────────────────────────────
empty_s3() {
  local env="$1"
  header "Phase 2 — Empty S3 Loki bucket ($env)"

  local bucket="observability-$env-loki-chunks-$ACCOUNT_ID"

  if $DRY_RUN; then
    warn "[DRY-RUN] Would empty versioned S3 bucket: s3://$bucket"
    return 0
  fi

  if ! aws s3api head-bucket --bucket "$bucket" --region "$REGION" 2>/dev/null; then
    warn "Bucket s3://$bucket not found — skipping."
    return 0
  fi

  info "Emptying versioned bucket s3://$bucket (objects + delete markers) ..."

  local total=0
  local tmp
  tmp=$(mktemp /tmp/s3-delete-XXXXXX.json)
  # shellcheck disable=SC2064
  trap "rm -f $tmp" EXIT

  while true; do
    local page
    page=$(aws s3api list-object-versions \
      --bucket "$bucket" \
      --region "$REGION" \
      --max-items 1000 \
      --output json 2>/dev/null || echo '{}')

    local payload
    payload=$(echo "$page" | jq -c '{
      Objects: [
        (.Versions     // [])[] | {Key: .Key, VersionId: .VersionId},
        (.DeleteMarkers // [])[] | {Key: .Key, VersionId: .VersionId}
      ],
      Quiet: true
    }')

    local count
    count=$(echo "$payload" | jq '.Objects | length')
    [[ "$count" -eq 0 ]] && break

    echo "$payload" > "$tmp"
    aws s3api delete-objects \
      --bucket "$bucket" \
      --region "$REGION" \
      --delete "file://$tmp" \
      --output json > /dev/null

    total=$((total + count))
    info "  Deleted $total object versions so far..."
  done

  rm -f "$tmp"
  ok "Bucket s3://$bucket emptied — $total versions removed."
}

# ── Phase 3: Terraform destroy ─────────────────────────────────────────────────
tf_destroy() {
  local env="$1"
  header "Phase 3 — Terraform destroy ($env)"

  local tf_dir="$REPO_ROOT/terraform/environments/$env"
  [[ -d "$tf_dir" ]] || die "Directory not found: $tf_dir"

  if $DRY_RUN; then
    warn "[DRY-RUN] Would run: terraform init + terraform destroy -auto-approve (in $tf_dir)"
    return 0
  fi

  export TF_VAR_aws_account_id="$ACCOUNT_ID"

  info "Initialising Terraform backend ($env)..."
  (cd "$tf_dir" && terraform init -input=false -reconfigure -no-color)

  info "Running terraform destroy for $env — this typically takes 20–40 minutes..."
  (cd "$tf_dir" && terraform destroy -auto-approve -input=false -no-color)

  ok "Terraform destroy complete for $env."
}

# ── Post-destroy verification ──────────────────────────────────────────────────
verify() {
  local env="$1"
  header "Verification — orphaned resources ($env)"
  echo ""

  local clusters
  clusters=$(aws eks list-clusters --region "$REGION" --output json 2>/dev/null | \
    jq -r ".clusters[] | select(contains(\"observability-$env\"))" 2>/dev/null || true)
  printf "  %-26s %s\n" "EKS clusters:" "${clusters:-none}"

  local vpcs
  vpcs=$(aws ec2 describe-vpcs --region "$REGION" \
    --filters "Name=tag:Environment,Values=$env" "Name=tag:Project,Values=observability-platform" \
    --query 'Vpcs[*].VpcId' --output text 2>/dev/null || true)
  printf "  %-26s %s\n" "VPCs:" "${vpcs:-none}"

  local amp
  amp=$(aws amp list-workspaces --region "$REGION" \
    --query "workspaces[?contains(alias, 'observability-$env')].alias" \
    --output text 2>/dev/null || true)
  printf "  %-26s %s\n" "AMP workspaces:" "${amp:-none}"

  local alb_count
  alb_count=$(aws resourcegroupstaggingapi get-resources \
    --tag-filters "Key=kubernetes.io/cluster/observability-$env,Values=owned" \
    --resource-type-filters "elasticloadbalancing:loadbalancer" \
    --region "$REGION" \
    --query 'ResourceTagMappingList | length(@)' \
    --output text 2>/dev/null || echo "0")
  printf "  %-26s %s\n" "ALBs remaining:" "${alb_count:-0}"

  local ebs
  ebs=$(aws ec2 describe-volumes --region "$REGION" \
    --filters "Name=status,Values=available" "Name=tag:Environment,Values=$env" \
    --query 'Volumes[*].VolumeId' --output text 2>/dev/null || true)
  printf "  %-26s %s\n" "Available EBS volumes:" "${ebs:-none}"
  echo ""
}

# ── Phase 4: Bootstrap destroy ─────────────────────────────────────────────────
destroy_bootstrap() {
  header "Phase 4 — Bootstrap destroy (GitHub Actions OIDC + CI IAM roles)"

  local tf_dir="$REPO_ROOT/terraform/bootstrap"
  if [[ ! -d "$tf_dir" ]]; then
    warn "Bootstrap directory not found ($tf_dir) — skipping."
    return 0
  fi

  if $DRY_RUN; then
    warn "[DRY-RUN] Would destroy bootstrap Terraform resources in $tf_dir"
    return 0
  fi

  if ! $SKIP_CONFIRM; then
    echo ""
    warn "This removes the GitHub Actions OIDC provider and CI IAM roles."
    warn "After this step, ALL GitHub Actions workflows lose AWS access."
    printf "Destroy bootstrap resources? [yes/no]: "
    read -r answer
    [[ "$answer" == "yes" ]] || { info "Skipping bootstrap destroy."; return 0; }
  fi

  info "Initialising bootstrap Terraform..."
  (cd "$tf_dir" && terraform init -input=false -reconfigure -no-color)

  info "Destroying bootstrap resources..."
  (cd "$tf_dir" && terraform destroy -auto-approve -input=false -no-color)

  ok "Bootstrap resources destroyed."
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${RED}${BOLD}║   SRE-Monitoring Observability Platform  —  TEARDOWN SCRIPT       ║${RESET}"
  echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  $DRY_RUN && warn "DRY-RUN mode active — no changes will be made."

  preflight

  # Resolve env list
  local envs=()
  [[ "$ENV" == "all" ]] && envs=(dev prod) || envs=("$ENV")

  # Confirm all targeted environments before touching anything
  if ! $DRY_RUN; then
    for env in "${envs[@]}"; do
      confirm "$env"
    done
  fi

  # Run phases for each environment in dependency order
  for env in "${envs[@]}"; do
    [[ "$PHASE" == "k8s"       || "$PHASE" == "all" ]] && teardown_k8s "$env"
    [[ "$PHASE" == "s3"        || "$PHASE" == "all" ]] && empty_s3 "$env"
    [[ "$PHASE" == "terraform" || "$PHASE" == "all" ]] && tf_destroy "$env"
    [[ "$PHASE" == "terraform" || "$PHASE" == "all" ]] && ! $DRY_RUN && verify "$env"
  done

  # Bootstrap is global — destroy once, after all envs
  [[ "$PHASE" == "bootstrap" || "$PHASE" == "all" ]] && destroy_bootstrap

  header "Teardown complete"
  echo ""
  ok "All requested phases finished."
  echo ""
  echo -e "${BOLD}Manual follow-up checklist:${RESET}"
  for env in "${envs[@]}"; do
    echo "  [ ] KMS keys (7-day pending deletion): AWS Console → KMS → Customer managed keys"
    echo "  [ ] CloudWatch log group: /aws/eks/observability-$env/cluster"
    echo "  [ ] Terraform state:  aws s3 rm s3://bathbucket31/observability-platform/$env/ --recursive"
  done
  echo "  [ ] DynamoDB lock table: dyning_table  (delete if no longer needed for any env)"
  echo "  [ ] Amazon Managed Grafana: verify workspace deletion in AWS Console → Amazon Grafana"
  echo ""
}

main
