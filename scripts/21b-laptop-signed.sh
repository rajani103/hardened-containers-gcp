#!/usr/bin/env bash
# DEMO 2c: the smarter bypass. A CLEAN image (zero CRITICALs) that did not come
# from our pipeline, signed with the REAL vulnz key (think: leaked or over-shared
# key). Still denied: it has no built-by-cloud-build provenance.
# Requires 04-policy-strict.sh.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
export PATH="$PATH:$HOME/go/bin"

crane copy --platform linux/amd64 "${BASE_REGISTRY}/python:${DHI_TAG}" "${IMAGE}:laptop" >/dev/null
REF="${IMAGE}@$(crane digest "${IMAGE}:laptop")"

say "signing the off-pipeline image with the real vulnz key"
gcloud beta container binauthz attestations sign-and-create \
  --artifact-url="$REF" \
  --attestor="$ATTESTOR" --attestor-project="$PROJECT_ID" \
  --keyversion-project="$PROJECT_ID" --keyversion-location="$REGION" \
  --keyversion-keyring="$KEYRING" --keyversion-key="$KEY" --keyversion=1

say "kubectl run the signed image (expected: denied, no provenance)"
kubectl run laptop --image="$REF" --restart=Never -- python -c 'print(1)' || true
