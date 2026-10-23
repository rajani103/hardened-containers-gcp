#!/usr/bin/env bash
# DEMO 2b: "someone skips CI". Copy the old image straight into our registry
# (no pipeline, no scan, no signature) and try to run it. Denied.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
export PATH="$PATH:$HOME/go/bin"

crane copy --platform linux/amd64 "docker.io/library/${BEFORE_BASE}-slim" "${IMAGE}:bypass" >/dev/null
DIGEST=$(crane digest "${IMAGE}:bypass")
echo "${IMAGE}@${DIGEST}" > "$ROOT/out/bypass-ref.txt"

say "kubectl run with an unsigned image from our own registry (expected: denied)"
kubectl run bypass --image="${IMAGE}@${DIGEST}" --restart=Never || true
