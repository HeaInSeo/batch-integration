#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REMOTE_HOST="${REMOTE_HOST:-seoy@100.123.80.48}"
VM_SSH_KEY="${VM_SSH_KEY:-/var/snap/multipass/common/data/multipassd/ssh-keys/id_rsa}"
VM_USER_AT_HOST="${VM_USER_AT_HOST:-ubuntu@10.113.24.254}"
VM_NAMESPACE="${VM_NAMESPACE:-batch-int-dev}"
FIXTURE_PATH="${FIXTURE_PATH:-${ROOT_DIR}/deploy/vm-lab/fixtures/kube-slint-jumi-ah-smoke-metrics.live.json}"
SUMMARY_PATH="${SUMMARY_PATH:-${ROOT_DIR}/artifacts/vm-lab/jumi-ah-smoke-live-sli-summary.json}"
GATE_PATH="${GATE_PATH:-${ROOT_DIR}/artifacts/vm-lab/gate/slint-gate-live-summary.json}"
POLICY_FILE="${POLICY_FILE:-${ROOT_DIR}/policy/vm-lab/jumi-ah-live-thresholds.yaml}"

RUN_STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
RUN_ID="${RUN_ID:-vm-lab-live-smoke-${RUN_STAMP}}"
SAMPLE_RUN_ID="${SAMPLE_RUN_ID:-vm-lab-live-smoke-sample-${RUN_STAMP}}"

JUMI_KEYS=(
  jumi_jobs_created_total
  jumi_artifacts_registered_total
  jumi_input_resolve_requests_total
  jumi_input_remote_fetch_total
  jumi_input_materializations_total
  jumi_sample_runs_finalized_total
  jumi_gc_evaluate_requests_total
)
AH_KEYS=(
  ah_artifacts_registered_total
  ah_resolve_requests_total
  ah_fallback_total
  ah_gc_backlog_bytes
)

ssh_vm() {
  ssh "${REMOTE_HOST}" "sudo ssh -i ${VM_SSH_KEY} ${VM_USER_AT_HOST} \"$1\""
}

collect_metric_values() {
  local service="$1"
  local prefix="$2"
  local tmp_name="$3"
  ssh_vm "sudo kubectl -n ${VM_NAMESPACE} run ${tmp_name} --image=busybox:1.36 --restart=Never --rm -i --command -- sh -c 'wget -qO- http://${service}:8080/metrics | grep ${prefix}_ || true'"
}

main() {
  mkdir -p "$(dirname "${FIXTURE_PATH}")" "$(dirname "${SUMMARY_PATH}")" "$(dirname "${GATE_PATH}")"

  local start_jumi
  local start_ah
  local end_jumi
  local end_ah
  start_jumi="$(mktemp)"
  start_ah="$(mktemp)"
  end_jumi="$(mktemp)"
  end_ah="$(mktemp)"
  trap "rm -f '${start_jumi}' '${start_ah}' '${end_jumi}' '${end_ah}'" EXIT

  collect_metric_values "jumi" "jumi" "metrics-jumi-start-${RUN_STAMP,,}" >"${start_jumi}"
  collect_metric_values "artifact-handoff" "ah" "metrics-ah-start-${RUN_STAMP,,}" >"${start_ah}"

  ssh_vm "env JUMI_RUN_ID=${RUN_ID} JUMI_SAMPLE_RUN_ID=${SAMPLE_RUN_ID} bash /home/ubuntu/vm-lab-jumi-smoke-remote.sh"

  collect_metric_values "jumi" "jumi" "metrics-jumi-end-${RUN_STAMP,,}" >"${end_jumi}"
  collect_metric_values "artifact-handoff" "ah" "metrics-ah-end-${RUN_STAMP,,}" >"${end_ah}"

  local started_at
  local finished_at
  started_at="$(date -u -d '30 seconds ago' +%Y-%m-%dT%H:%M:%SZ)"
  finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  python3 - <<PY
import json
from pathlib import Path

fixture_path = Path("${FIXTURE_PATH}")
started_at = "${started_at}"
finished_at = "${finished_at}"
run_id = "${RUN_ID}"
sample_run_id = "${SAMPLE_RUN_ID}"
start_jumi_path = Path("${start_jumi}")
start_ah_path = Path("${start_ah}")
end_jumi_path = Path("${end_jumi}")
end_ah_path = Path("${end_ah}")
jumi_keys = [
    "jumi_jobs_created_total",
    "jumi_artifacts_registered_total",
    "jumi_input_resolve_requests_total",
    "jumi_input_remote_fetch_total",
    "jumi_input_materializations_total",
    "jumi_sample_runs_finalized_total",
    "jumi_gc_evaluate_requests_total",
]
ah_keys = [
    "ah_artifacts_registered_total",
    "ah_resolve_requests_total",
    "ah_fallback_total",
    "ah_gc_backlog_bytes",
]

def parse_metrics(path):
    values = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) != 2:
            continue
        key, value = parts
        try:
            values[key] = float(value)
        except ValueError:
            continue
    return values

start_values = parse_metrics(start_jumi_path)
start_values.update(parse_metrics(start_ah_path))
end_values = parse_metrics(end_jumi_path)
end_values.update(parse_metrics(end_ah_path))

start_metrics = {k: start_values.get(k, 0.0) for k in jumi_keys + ah_keys}
end_metrics = {k: end_values.get(k, 0.0) for k in jumi_keys + ah_keys}

fixture = {
    "runId": run_id,
    "startedAt": started_at,
    "finishedAt": finished_at,
    "method": "OutsideSnapshot",
    "tags": {
        "env": "vm-lab",
        "profile": "jumi-ah-live-smoke",
        "source": "batch-integration",
        "collection": "live",
    },
    "evidencePaths": {
        "smoke_fixture": "deploy/vm-lab/fixtures/jumi-handoff-smoke.json",
        "smoke_result_doc": "docs/status/VM_LAB_JUMI_AH_SMOKE_RESULT_2026-04-22.md",
        "live_run_id": run_id,
        "live_sample_run_id": sample_run_id,
    },
    "startMetrics": start_metrics,
    "endMetrics": end_metrics,
}
fixture_path.write_text(json.dumps(fixture, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

  FIXTURE_PATH="${FIXTURE_PATH}" OUTPUT_PATH="${SUMMARY_PATH}" PROFILE="smoke" \
    bash "${ROOT_DIR}/scripts/generate-kubeslint-vm-lab-summary.sh"
  MEASUREMENT_SUMMARY="${SUMMARY_PATH}" POLICY_FILE="${POLICY_FILE}" OUTPUT_FILE="${GATE_PATH}" \
    bash "${ROOT_DIR}/scripts/run-kubeslint-vm-lab-gate.sh"

  python3 - <<PY
import json
from pathlib import Path

fixture = json.loads(Path("${FIXTURE_PATH}").read_text(encoding="utf-8"))
summary = json.loads(Path("${SUMMARY_PATH}").read_text(encoding="utf-8"))
gate = json.loads(Path("${GATE_PATH}").read_text(encoding="utf-8"))

print(f"fixture: ${FIXTURE_PATH}")
print(f"summary: ${SUMMARY_PATH}")
print(f"gate: ${GATE_PATH}")
print(f"live_run_id={fixture['runId']}")
print(f"live_sample_run_id={fixture['evidencePaths']['live_sample_run_id']}")
print(f"results={len(summary.get('results', []))} gate_result={gate.get('gate_result')}")
print(f"evaluation_status={gate.get('evaluation_status')} measurement_status={gate.get('measurement_status')}")
print(f"overall_message={gate.get('overall_message')}")
PY
}

main "$@"
