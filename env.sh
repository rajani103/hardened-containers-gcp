# Source this before running any script:  source env.sh
export PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
export PROJECT_NUMBER="$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')"

export REGION="asia-south1"
export ZONE="asia-south1-a"
export SCAN_LOCATION="asia"            # On-Demand Scanning location: us | europe | asia

export REPO="demo"                     # app images
export BASE_REPO="hardened"                # mirrored hardened base images
export IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO}/app"
export BASE_REGISTRY="${REGION}-docker.pkg.dev/${PROJECT_ID}/${BASE_REPO}"

export BEFORE_BASE="python:3.13"       # the "400 CVEs" image
export DHI_TAG="3.13-alpine3.23"       # dhi.io/python:<tag> and <tag>-dev

export CLUSTER="cve-demo"
export KEYRING="binauthz"
export KEY="vulnz-signer"
export NOTE_ID="vulnz-note"
export ATTESTOR="vulnz-attestor"
export BUILDER_SA="cve-demo-builder"
export BUILDER_SA_EMAIL="${BUILDER_SA}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "project=${PROJECT_ID} region=${REGION} image=${IMAGE}"
