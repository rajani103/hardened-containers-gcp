#!/usr/bin/env bash
# GKE Standard cluster with Binary Authorization enforcing the project policy.
set -euo pipefail
source "$(dirname "$0")/../env.sh"

gcloud container clusters create "$CLUSTER" \
  --zone="$ZONE" --num-nodes=2 --machine-type=e2-standard-2 \
  --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE \
  --workload-pool="${PROJECT_ID}.svc.id.goog" \
  --shielded-secure-boot --shielded-integrity-monitoring

gcloud container clusters get-credentials "$CLUSTER" --zone="$ZONE"
kubectl get nodes
