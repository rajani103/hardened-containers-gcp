#!/usr/bin/env bash
# Mirror the hardened base images into Artifact Registry.
# Production habit: CI builds from your own registry, not from the internet.
# Uses crane (registry-to-registry copy, keeps the multi-arch index and digest)
# instead of docker pull/tag/push, which proved flaky from Cloud Shell's daemon.
set -euo pipefail
source "$(dirname "$0")/../env.sh"
export PATH="$PATH:$HOME/go/bin"

command -v crane >/dev/null || go install github.com/google/go-containerregistry/cmd/crane@v0.20.2

echo "Log in with your Docker ID if prompted (a read-only access token is best):"
docker login dhi.io

for tag in "${DHI_TAG}-dev" "${DHI_TAG}"; do
  crane copy "dhi.io/python:${tag}" "${BASE_REGISTRY}/python:${tag}"
done
gcloud artifacts docker images list "${BASE_REGISTRY}/python" --include-tags \
  --format='table(tags,version.basename())'
