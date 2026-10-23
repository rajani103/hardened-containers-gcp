#!/usr/bin/env bash
# One-time: APIs, Artifact Registry repos, a least-privilege Cloud Build service account.
set -euo pipefail
source "$(dirname "$0")/../env.sh"

gcloud services enable \
  container.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com \
  containeranalysis.googleapis.com containerscanning.googleapis.com \
  ondemandscanning.googleapis.com binaryauthorization.googleapis.com cloudkms.googleapis.com \
  pubsub.googleapis.com

for r in "$REPO" "$BASE_REPO"; do
  gcloud artifacts repositories create "$r" --repository-format=docker \
    --location="$REGION" --description="cve-demo $r" 2>/dev/null || echo "repo $r exists"
done
gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet

gcloud iam service-accounts create "$BUILDER_SA" \
  --display-name="cve-demo Cloud Build" 2>/dev/null || echo "SA exists"

for role in \
  roles/artifactregistry.writer \
  roles/storage.objectViewer \
  roles/logging.logWriter \
  roles/ondemandscanning.admin \
  roles/binaryauthorization.attestorsViewer \
  roles/cloudkms.signerVerifier \
  roles/containeranalysis.notes.attacher \
  roles/containeranalysis.occurrences.editor; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${BUILDER_SA_EMAIL}" --role="$role" --condition=None --quiet >/dev/null
  echo "granted $role"
done

# Moving the "prod" tag to a new digest needs tags.update/delete: repoAdmin,
# scoped to the app repo only (not project-wide).
gcloud artifacts repositories add-iam-policy-binding "$REPO" --location="$REGION" \
  --member="serviceAccount:${BUILDER_SA_EMAIL}" --role=roles/artifactregistry.repoAdmin --quiet >/dev/null
echo "granted roles/artifactregistry.repoAdmin on repo $REPO"

# Local on-demand scans need this gcloud component.
gcloud components install local-extract --quiet || \
  echo "If gcloud was installed via apt/brew, install the local-extract component that way."
