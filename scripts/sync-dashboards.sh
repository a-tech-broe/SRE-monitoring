#!/usr/bin/env bash
set -euo pipefail

# Uploads all dashboard JSON files to Grafana via the HTTP API.
# Requires GRAFANA_URL and GRAFANA_SA_TOKEN to be set in the environment.

ENV="${1:-dev}"
DASHBOARDS_DIR="$(dirname "$0")/../dashboards"

: "${GRAFANA_URL:?GRAFANA_URL must be set}"
: "${GRAFANA_SA_TOKEN:?GRAFANA_SA_TOKEN must be set}"

log() { echo "[sync-dashboards:$ENV] $*"; }

upload_dashboard() {
  local file="$1"
  local title folder_uid

  title=$(jq -r '.title' "$file")
  folder_uid="$(dirname "$file" | xargs basename)"

  log "Uploading: $title (folder: $folder_uid)"

  local payload
  payload=$(jq -n \
    --argjson dashboard "$(cat "$file")" \
    --arg folderUid "$folder_uid" \
    '{
      dashboard: $dashboard,
      folderUid: $folderUid,
      overwrite: true,
      message: "Synced from SRE-monitoring repo"
    }')

  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $GRAFANA_SA_TOKEN" \
    -H "Content-Type: application/json" \
    -X POST \
    -d "$payload" \
    "${GRAFANA_URL%/}/api/dashboards/import")

  if [[ "$status" == "200" ]]; then
    log "  OK: $title"
  else
    log "  ERROR ($status): $title"
    return 1
  fi
}

ensure_folder() {
  local uid="$1"
  local title="$2"

  local existing
  existing=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: Bearer $GRAFANA_SA_TOKEN" \
    "${GRAFANA_URL%/}/api/folders/$uid")

  if [[ "$existing" != "200" ]]; then
    log "Creating folder: $title ($uid)"
    curl -s -X POST \
      -H "Authorization: Bearer $GRAFANA_SA_TOKEN" \
      -H "Content-Type: application/json" \
      -d "{\"uid\":\"$uid\",\"title\":\"$title\"}" \
      "${GRAFANA_URL%/}/api/folders" >/dev/null
  fi
}

ensure_folder "kubernetes"     "Kubernetes"
ensure_folder "application"    "Application"
ensure_folder "infrastructure" "Infrastructure"

while IFS= read -r -d '' file; do
  upload_dashboard "$file"
done < <(find "$DASHBOARDS_DIR" -name '*.json' -print0)

log "Dashboard sync complete."
