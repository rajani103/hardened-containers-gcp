#!/usr/bin/env bash
# From 400 CVEs to Zero — the whole demo, one act at a time.
# Press Enter to start each act. Usage:  ./run-demo.sh        (all acts)
#                                        ./run-demo.sh 3      (start at act 3)
set -uo pipefail
cd "$(dirname "$0")"
export PROJECT_ID="${PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}"
gcloud config set project "$PROJECT_ID" >/dev/null 2>&1
source scripts/lib.sh
START="${1:-1}"

C=$'\033[1;36m'; G=$'\033[1;32m'; D=$'\033[2m'; N=$'\033[0m'
act()   { clear; printf '\n%s━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n  ACT %s · %s\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%s\n\n' "$C" "$1" "$2" "$N"; }
pause() { printf '\n%s[ Enter → %s ]%s' "$D" "$*" "$N"; read -r _; }
show()  { printf '%s$ %s%s\n' "$G" "$*" "$N"; }

# ---- quiet prerequisites (off camera) ----
gcloud container clusters get-credentials "$CLUSTER" --zone "$ZONE" >/dev/null 2>&1
command -v crane >/dev/null || go install github.com/google/go-containerregistry/cmd/crane@v0.20.2 >/dev/null 2>&1
dpkg -s google-cloud-cli-local-extract >/dev/null 2>&1 || \
  sudo apt-get install -y -qq google-cloud-cli-local-extract >/dev/null 2>&1
kubectl delete pod bypass laptop --ignore-not-found >/dev/null 2>&1

# ============================================================================
if (( START <= 1 )); then
act 1 "Same code, two base images"
pause "show the only difference between the two Dockerfiles"
show "diff Dockerfile.before Dockerfile.dhi"
diff --color=always Dockerfile.before Dockerfile.dhi
pause "build both, scan both, compare"
show "./scripts/10-demo1-scan.sh"
./scripts/10-demo1-scan.sh
pause "next act"
fi

# ============================================================================
if (( START <= 2 )); then
act 2 "One pipeline, two images"
echo "Stage 1  build → scan → gate (fail on CRITICAL) → Cloud Build pushes (+ provenance)"
echo "Stage 2  re-scan the pushed digest → sign with Cloud KMS → tag prod"
pause "run the hardened image, then the old image, through the SAME pipeline"
show "./scripts/20-pipeline.sh"
./scripts/20-pipeline.sh
pause "next act"
fi

# ============================================================================
if (( START <= 3 )); then
act 3 "Deploy the signed image, by digest"
show "./scripts/22-deploy-signed.sh"
./scripts/22-deploy-signed.sh
pause "next act"
fi

# ============================================================================
if (( START <= 4 )); then
act 4 "Bypass #1: skip CI, push straight to the registry"
show "./scripts/21-bypass.sh"
./scripts/21-bypass.sh
pause "next act"
fi

# ============================================================================
if (( START <= 5 )); then
act 5 "Bypass #2: clean image, REAL signing key, built outside the pipeline"
show "./scripts/21b-laptop-signed.sh"
./scripts/21b-laptop-signed.sh
pause "next act"
fi

# ============================================================================
if (( START <= 6 )); then
act 6 "Zero lasts until the next CVE drops: the self-healing loop"
BEFORE_REF=$(running_ref)
echo "production is running: ${BEFORE_REF##*@}"
pause "start the bot"
show "./scripts/30-cve-bot.sh &"
./scripts/30-cve-bot.sh & BOT=$!
sleep 12
pause "replay a real Artifact Analysis finding on the running image"
show "./scripts/31-simulate-cve.sh"
for i in $(seq 1 10); do
  ./scripts/31-simulate-cve.sh && break
  echo "  (scanner still indexing the new image, retrying in 30s)"; sleep 30
done
# wait until production moves to a new digest, or the bot gives up
for i in $(seq 1 90); do
  [[ "$(running_ref)" != "$BEFORE_REF" ]] && break
  kill -0 "$BOT" 2>/dev/null || break
  sleep 10
done
sleep 8; kill "$BOT" 2>/dev/null; wait "$BOT" 2>/dev/null
pause "finish"
fi

clear
printf '\n%s  Demo complete.%s\n\n' "$C" "$N"
echo "  production: $(running_ref)"
echo
