#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE_SSH_TARGET="${REMOTE_SSH_TARGET:-seoy@100.123.80.48}"
REMOTE_KUBECONFIG="${REMOTE_KUBECONFIG:-/opt/go/src/github.com/HeaInSeo/infra-lab/kubeconfig}"
REMOTE_TMP_DIR="${REMOTE_TMP_DIR:-/tmp/shift-left-observability}"
NAMESPACE="${NAMESPACE:-shift-left-observability}"
SITE_HOSTNAME="${SITE_HOSTNAME:-shift-left-observability.10.113.24.96.nip.io}"
SITE_SOURCE_DIR="${SITE_SOURCE_DIR:-${ROOT_DIR}/deploy/vm-lab/shift-left-observability/site}"
SLI_SUMMARY_PATH="${SLI_SUMMARY_PATH:-${ROOT_DIR}/artifacts/vm-lab/jumi-ah-smoke-live-sli-summary.json}"
GATE_SUMMARY_PATH="${GATE_SUMMARY_PATH:-${ROOT_DIR}/artifacts/vm-lab/gate/slint-gate-live-summary.json}"
POLICY_FILE="${POLICY_FILE:-${ROOT_DIR}/../JUMI/policy/devspace/jumi-ah-live-thresholds.yaml}"

require_file() {
  [[ -f "$1" ]] || {
    echo "missing file: $1" >&2
    exit 1
  }
}

require_value() {
  [[ -n "$2" ]] || {
    echo "missing required ${1}" >&2
    exit 1
  }
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing command: $1" >&2
    exit 1
  }
}

need_cmd jq
need_cmd scp
need_cmd ssh

require_value "SLI_SUMMARY_PATH" "$SLI_SUMMARY_PATH"
require_value "GATE_SUMMARY_PATH" "$GATE_SUMMARY_PATH"
require_file "$SLI_SUMMARY_PATH"
require_file "$GATE_SUMMARY_PATH"
require_file "$POLICY_FILE"
require_file "${SITE_SOURCE_DIR}/index.html"

bundle_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$bundle_dir"
}
trap cleanup EXIT

cp "${SITE_SOURCE_DIR}/index.html" "${bundle_dir}/index.html"
cp "$SLI_SUMMARY_PATH" "${bundle_dir}/latest-sli-summary.json"
cp "$GATE_SUMMARY_PATH" "${bundle_dir}/latest-gate-summary.json"

run_id="$(jq -r '.config.runId // empty' "$SLI_SUMMARY_PATH")"
sample_run_id="$(jq -r '.config.evidencePaths.live_sample_run_id // empty' "$SLI_SUMMARY_PATH")"
gate_result="$(jq -r '.gate_result // empty' "$GATE_SUMMARY_PATH")"
evaluated_at="$(jq -r '.evaluated_at // empty' "$GATE_SUMMARY_PATH")"

cat > "${bundle_dir}/metadata.json" <<EOF
{
  "published_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "run_id": "${run_id}",
  "sample_run_id": "${sample_run_id}",
  "gate_result": "${gate_result}",
  "evaluated_at": "${evaluated_at}",
  "policy_file": "$(basename "$POLICY_FILE")",
  "site_hostname": "${SITE_HOSTNAME}"
}
EOF

ssh -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE_SSH_TARGET" "rm -rf '$REMOTE_TMP_DIR' && mkdir -p '$REMOTE_TMP_DIR/site'"
scp -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${bundle_dir}/"* "${REMOTE_SSH_TARGET}:${REMOTE_TMP_DIR}/site/"
scp -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -r "${ROOT_DIR}/deploy/vm-lab/shift-left-observability" "${REMOTE_SSH_TARGET}:${REMOTE_TMP_DIR}/"

ssh -F /dev/null -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$REMOTE_SSH_TARGET" "
  export KUBECONFIG='${REMOTE_KUBECONFIG}'
  kubectl apply -k '${REMOTE_TMP_DIR}/shift-left-observability'
  kubectl -n '${NAMESPACE}' create configmap shift-left-observability-site \
    --from-file='${REMOTE_TMP_DIR}/site' \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl -n '${NAMESPACE}' rollout restart deploy/shift-left-observability
  kubectl -n '${NAMESPACE}' rollout status deploy/shift-left-observability --timeout=180s
  kubectl -n '${NAMESPACE}' get svc,httproute,pod
"

echo "published shift-left observability to http://${SITE_HOSTNAME}"
