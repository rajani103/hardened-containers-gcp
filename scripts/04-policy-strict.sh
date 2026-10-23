#!/usr/bin/env bash
# Run AFTER the first successful Cloud Build (that creates built-by-cloud-build).
# Policy now requires provenance AND a passed vulnerability gate.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

gcloud container binauthz attestors describe built-by-cloud-build >/dev/null \
  || { echo "built-by-cloud-build attestor not found yet: run 20-pipeline.sh first"; exit 1; }

sed "s/PROJECT_ID/${PROJECT_ID}/g" "$ROOT/policy.yaml" > /tmp/binauthz-policy.yaml
gcloud container binauthz policy import /tmp/binauthz-policy.yaml
gcloud container binauthz policy export
echo "Policy changes can take a few minutes to apply."
