#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUMMARY_SCRIPT="${ROOT_DIR}/scripts/generate-kubeslint-vm-lab-summary.sh"
GATE_SCRIPT="${ROOT_DIR}/scripts/run-kubeslint-vm-lab-gate.sh"
SUMMARY_PATH="${SUMMARY_PATH:-${ROOT_DIR}/artifacts/vm-lab/jumi-ah-smoke-sli-summary.json}"
GATE_PATH="${GATE_PATH:-${ROOT_DIR}/artifacts/vm-lab/gate/slint-gate-summary.json}"

bash "${SUMMARY_SCRIPT}"
bash "${GATE_SCRIPT}"

python3 - <<PY
import json
from pathlib import Path

summary_path = Path("${SUMMARY_PATH}")
gate_path = Path("${GATE_PATH}")

summary = json.loads(summary_path.read_text(encoding="utf-8"))
gate = json.loads(gate_path.read_text(encoding="utf-8"))

print(f"summary: {summary_path}")
print(f"gate: {gate_path}")
print(f"results={len(summary.get('results', []))} gate_result={gate.get('gate_result')}")
print(f"evaluation_status={gate.get('evaluation_status')} measurement_status={gate.get('measurement_status')}")
print(f"overall_message={gate.get('overall_message')}")
PY
