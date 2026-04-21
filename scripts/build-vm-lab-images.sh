#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REGISTRY_HOST="${REGISTRY_HOST:-harbor.10.113.24.96.nip.io}"
REGISTRY_PROJECT="${REGISTRY_PROJECT:-batch-int}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
OCI_TOOL="${OCI_TOOL:-podman}"

AH_IMAGE="${REGISTRY_HOST}/${REGISTRY_PROJECT}/artifact-handoff:${IMAGE_TAG}"
JUMI_IMAGE="${REGISTRY_HOST}/${REGISTRY_PROJECT}/jumi:${IMAGE_TAG}"

echo "Using OCI tool: ${OCI_TOOL}"
echo "Artifact Handoff image: ${AH_IMAGE}"
echo "JUMI image: ${JUMI_IMAGE}"

"${OCI_TOOL}" build \
  -f "${ROOT_DIR}/../artifact-handoff/Containerfile" \
  -t "${AH_IMAGE}" \
  "${ROOT_DIR}/../artifact-handoff"

"${OCI_TOOL}" build \
  -f "${ROOT_DIR}/../JUMI/Containerfile" \
  -t "${JUMI_IMAGE}" \
  "${ROOT_DIR}/../JUMI"

"${OCI_TOOL}" push "${AH_IMAGE}"
"${OCI_TOOL}" push "${JUMI_IMAGE}"

echo "Pushed:"
echo "  ${AH_IMAGE}"
echo "  ${JUMI_IMAGE}"
