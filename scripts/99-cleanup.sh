#!/usr/bin/env bash
# Tear down everything that costs money. KMS keys can't be deleted, only
# their versions destroyed; the keyring itself is free.
set -uo pipefail
source "$(dirname "$0")/../env.sh"

gcloud pubsub subscriptions delete cve-bot --quiet
gcloud container clusters delete "$CLUSTER" --zone="$ZONE" --quiet
gcloud artifacts repositories delete "$REPO" --location="$REGION" --quiet
gcloud artifacts repositories delete "$BASE_REPO" --location="$REGION" --quiet
gcloud kms keys versions destroy 1 --key="$KEY" --keyring="$KEYRING" --location="$REGION" --quiet
gcloud container binauthz attestors delete "$ATTESTOR" --quiet

# Reset the policy to allow-all so other workloads in this project aren't blocked.
cat > /tmp/allow-all.yaml <<EOF
globalPolicyEvaluationMode: ENABLE
defaultAdmissionRule:
  evaluationMode: ALWAYS_ALLOW
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
name: projects/${PROJECT_ID}/policy
EOF
gcloud container binauthz policy import /tmp/allow-all.yaml
