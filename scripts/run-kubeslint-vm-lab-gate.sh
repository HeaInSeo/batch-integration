#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MEASUREMENT_SUMMARY="${MEASUREMENT_SUMMARY:-${ROOT_DIR}/artifacts/vm-lab/jumi-ah-smoke-sli-summary.json}"
POLICY_FILE="${POLICY_FILE:-${ROOT_DIR}/policy/vm-lab/jumi-ah-smoke-thresholds.yaml}"
OUTPUT_FILE="${OUTPUT_FILE:-${ROOT_DIR}/artifacts/vm-lab/gate/slint-gate-summary.json}"

mkdir -p "$(dirname "${OUTPUT_FILE}")"

python3 /opt/go/src/github.com/HeaInSeo/kube-slint/hack/slint_gate.py \
  --measurement-summary "${MEASUREMENT_SUMMARY}" \
  --policy "${POLICY_FILE}" \
  --output "${OUTPUT_FILE}"
