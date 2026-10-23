#!/usr/bin/env bash
# DEMO 2d (optional): emergency override. The pod runs, but it's audited.
set -euo pipefail
source "$(dirname "$0")/../env.sh"
REF=$(cat "$(dirname "$0")/../out/bypass-ref.txt")

kubectl run breakglass --image="$REF" --restart=Never \
  --annotations="alpha.image-policy.k8s.io/break-glass=true"
kubectl get pod breakglass

cat <<EOF

Show it in Logs Explorer (allow a minute for logs to arrive):

  resource.type="k8s_cluster"
  logName:"cloudaudit.googleapis.com%2Factivity"
  protoPayload.request.metadata.annotations."alpha.image-policy.k8s.io/break-glass"="true"

Denied deploys:

  resource.type="k8s_cluster"
  protoPayload.response.reason="VIOLATES_POLICY"
EOF
