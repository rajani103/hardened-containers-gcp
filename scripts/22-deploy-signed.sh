#!/usr/bin/env bash
# DEMO 2d: deploy the signed image BY DIGEST, prove it runs, show there's no shell.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

DIGEST=$(gcloud artifacts docker images describe "${IMAGE}:prod" --format='value(image_summary.digest)')
export IMAGE_REF="${IMAGE}@${DIGEST}"
say "deploying ${IMAGE_REF}"

envsubst < "$ROOT/k8s/deployment.yaml" | kubectl apply -f -
kubectl rollout status deploy/cve-demo --timeout=180s

kubectl port-forward deploy/cve-demo 8080:8080 >/dev/null 2>&1 &
PF=$!; sleep 3
curl -s localhost:8080/; echo
kill $PF 2>/dev/null || true

say "try to get a shell in the running pod"
kubectl exec deploy/cve-demo -- sh -c 'id' || say "no shell in the image"
