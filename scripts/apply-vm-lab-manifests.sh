#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUSTOMIZE_DIR="${ROOT_DIR}/deploy/vm-lab"

REGISTRY_HOST="${REGISTRY_HOST:-harbor.10.113.24.96.nip.io}"
REGISTRY_PROJECT="${REGISTRY_PROJECT:-batch-int}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
KUBECTL_BIN="${KUBECTL_BIN:-kubectl}"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

cp "${KUSTOMIZE_DIR}/kustomization.yaml" "${TMP_DIR}/kustomization.yaml"
cp "${KUSTOMIZE_DIR}/namespace.yaml" "${TMP_DIR}/namespace.yaml"
cp "${KUSTOMIZE_DIR}/artifact-handoff.yaml" "${TMP_DIR}/artifact-handoff.yaml"
cp "${KUSTOMIZE_DIR}/jumi.yaml" "${TMP_DIR}/jumi.yaml"

python3 - <<PY
from pathlib import Path
path = Path("${TMP_DIR}/kustomization.yaml")
text = path.read_text()
text = text.replace("harbor.10.113.24.96.nip.io/batch-int/artifact-handoff", f"${REGISTRY_HOST}/${REGISTRY_PROJECT}/artifact-handoff")
text = text.replace("harbor.10.113.24.96.nip.io/batch-int/jumi", f"${REGISTRY_HOST}/${REGISTRY_PROJECT}/jumi")
text = text.replace("newTag: dev", "newTag: ${IMAGE_TAG}")
path.write_text(text)
PY

"${KUBECTL_BIN}" apply -k "${TMP_DIR}"
