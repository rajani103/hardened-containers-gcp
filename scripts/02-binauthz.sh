#!/usr/bin/env bash
# KMS signing key, Container Analysis note, attestor, and the project policy.
set -euo pipefail
source "$(dirname "$0")/../env.sh"

gcloud kms keyrings create "$KEYRING" --location="$REGION" 2>/dev/null || echo "keyring exists"
gcloud kms keys create "$KEY" --keyring="$KEYRING" --location="$REGION" \
  --purpose=asymmetric-signing --default-algorithm=ec-sign-p256-sha256 \
  2>/dev/null || echo "key exists"

curl -sf -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/notes/?noteId=${NOTE_ID}" \
  --data '{"attestation":{"hint":{"human_readable_name":"Vulnerability gate passed"}}}' \
  >/dev/null || echo "note exists"

gcloud container binauthz attestors create "$ATTESTOR" \
  --attestation-authority-note="$NOTE_ID" \
  --attestation-authority-note-project="$PROJECT_ID" 2>/dev/null || echo "attestor exists"

gcloud beta container binauthz attestors public-keys add \
  --attestor="$ATTESTOR" \
  --keyversion-project="$PROJECT_ID" --keyversion-location="$REGION" \
  --keyversion-keyring="$KEYRING" --keyversion-key="$KEY" --keyversion=1 \
  2>/dev/null || echo "public key already on attestor"

# Binary Authorization's service agent must be able to read attestations.
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-binaryauthorization.iam.gserviceaccount.com" \
  --role=roles/containeranalysis.notes.occurrences.viewer --condition=None --quiet >/dev/null

# Start with the vulnz attestor only. built-by-cloud-build doesn't exist until
# the first Cloud Build runs; 04-policy-strict.sh adds it after that.
cat > /tmp/binauthz-policy.yaml <<EOF
globalPolicyEvaluationMode: ENABLE
defaultAdmissionRule:
  evaluationMode: REQUIRE_ATTESTATION
  enforcementMode: ENFORCED_BLOCK_AND_AUDIT_LOG
  requireAttestationsBy:
    - projects/${PROJECT_ID}/attestors/${ATTESTOR}
name: projects/${PROJECT_ID}/policy
EOF
gcloud container binauthz policy import /tmp/binauthz-policy.yaml
gcloud container binauthz policy export
