#!/usr/bin/env bash
# DEMO 3 trigger. You can't schedule a real CVE disclosure for a demo,
# so this REPLAYS a real notification: it finds a real HIGH/CRITICAL occurrence
# that Artifact Analysis recorded on the running image and re-publishes its
# notification to the same topic. The occurrence is real; only the delivery is replayed.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

RUNNING=$(running_ref)
[[ -n "$RUNNING" ]] || { echo "nothing deployed: run 22-deploy-signed.sh"; exit 1; }
say "running image: ${RUNNING}"

occs=$(curl -sf -G -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  "https://containeranalysis.googleapis.com/v1/projects/${PROJECT_ID}/occurrences" \
  --data-urlencode "filter=kind=\"VULNERABILITY\" AND resourceUrl=\"https://${RUNNING}\"" \
  --data-urlencode "pageSize=200")

name=$(jq -r '[.occurrences[]? | select(.vulnerability.effectiveSeverity=="HIGH" or .vulnerability.effectiveSeverity=="CRITICAL")][0].name // empty' <<<"$occs")
[[ -n "$name" ]] || { echo "no HIGH/CRITICAL occurrence on the running image yet (automatic scan can take a few minutes after push)"; exit 1; }

jq -r --arg n "$name" '.occurrences[] | select(.name==$n) |
  "found: \(.noteName | split("/") | last)  \(.vulnerability.effectiveSeverity)  \(.vulnerability.packageIssue[0].affectedPackage // "")"' <<<"$occs"

msg=$(jq -cn --arg n "$name" --arg t "$(date -u +%Y-%m-%dT%H:%M:%S.000000000Z)" \
  '{name:$n, kind:"VULNERABILITY", notificationTime:$t}')
gcloud pubsub topics publish container-analysis-occurrences-v1 --message="$msg"
say "notification replayed. watch the bot."
