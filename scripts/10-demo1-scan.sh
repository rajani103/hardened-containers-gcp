#!/usr/bin/env bash
# DEMO 1: same app, two bases. Scan both, compare.
# Scans take a minute or two each: pre-run them, then re-run one live.
set -euo pipefail
source "$(dirname "$0")/../env.sh"
cd "$(dirname "$0")/.."
mkdir -p out

docker build -q -f Dockerfile.before -t app:before .
docker build -q -f Dockerfile.dhi    -t app:dhi .

for t in before dhi; do
  echo; echo "=== app:${t} ==="
  scan=$(gcloud artifacts docker images scan "app:${t}" \
           --location="$SCAN_LOCATION" --format='value(response.scan)')
  gcloud artifacts docker images list-vulnerabilities "$scan" \
    --format='value(vulnerability.effectiveSeverity)' > "out/${t}-severities.txt"
  sort "out/${t}-severities.txt" | uniq -c
  echo "TOTAL: $(wc -l < "out/${t}-severities.txt")"
done

echo; echo "=== size ==="
docker images app --format 'table {{.Tag}}\t{{.Size}}'

echo; echo "=== can an attacker get a shell? ==="
echo "before:"; docker run --rm --entrypoint sh app:before -c 'echo "yes: $(id)"'
echo "dhi:";    docker run --rm --entrypoint sh app:dhi -c 'echo yes' 2>&1 | tail -1 || true
