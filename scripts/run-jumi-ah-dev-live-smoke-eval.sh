#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

FIXTURE_PATH="${FIXTURE_PATH:-${ROOT_DIR}/artifacts/vm-lab/kube-slint-jumi-ah-smoke-metrics.live.json}" \
SUMMARY_PATH="${SUMMARY_PATH:-${ROOT_DIR}/artifacts/vm-lab/jumi-ah-smoke-live-sli-summary.json}" \
GATE_PATH="${GATE_PATH:-${ROOT_DIR}/artifacts/vm-lab/gate/slint-gate-live-summary.json}" \
POLICY_FILE="${POLICY_FILE:-${ROOT_DIR}/../JUMI/policy/devspace/jumi-ah-live-thresholds.yaml}" \
SLINT_GATE_BIN="${SLINT_GATE_BIN:-${ROOT_DIR}/../kube-slint/slint-gate}" \
ALLOW_LOCAL_CHECKOUT_FALLBACK="${ALLOW_LOCAL_CHECKOUT_FALLBACK:-true}" \
PUBLISH_SHIFT_LEFT_OBSERVABILITY_SCRIPT="${PUBLISH_SHIFT_LEFT_OBSERVABILITY_SCRIPT:-${ROOT_DIR}/../infra-lab/scripts/host/publish-shift-left-observability.sh}" \
exec bash "${ROOT_DIR}/../JUMI/scripts/run-jumi-ah-dev-live-smoke-eval.sh" "$@"
