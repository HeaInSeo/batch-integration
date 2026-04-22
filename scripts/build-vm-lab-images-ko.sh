#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

REGISTRY_HOST="${REGISTRY_HOST:-harbor.10.113.24.96.nip.io}"
REGISTRY_PROJECT="${REGISTRY_PROJECT:-batch-int}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
KO_BIN="${KO_BIN:-ko}"
PLATFORMS="${PLATFORMS:-linux/amd64}"

export KO_DOCKER_REPO="${REGISTRY_HOST}/${REGISTRY_PROJECT}"
export KO_DEFAULTBASEIMAGE="${KO_DEFAULTBASEIMAGE:-cgr.dev/chainguard/static:latest}"

echo "Using ko binary: ${KO_BIN}"
echo "KO_DOCKER_REPO=${KO_DOCKER_REPO}"
echo "IMAGE_TAG=${IMAGE_TAG}"
echo "PLATFORMS=${PLATFORMS}"

(
  cd "${ROOT_DIR}/../artifact-handoff"
  "${KO_BIN}" build --bare --platform="${PLATFORMS}" --tags="${IMAGE_TAG}" ./cmd/artifact-handoff-resolver
)

(
  cd "${ROOT_DIR}/../JUMI"
  "${KO_BIN}" build --bare --platform="${PLATFORMS}" --tags="${IMAGE_TAG}" ./cmd/jumi
)
