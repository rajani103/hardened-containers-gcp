# Shared helpers. Sourced by the demo scripts.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/env.sh" >/dev/null
mkdir -p "$ROOT/out"
export PATH="$PATH:$HOME/go/bin"

# Progress goes to stderr so callers can capture ship's result and still show the log.
say() { printf '\n\033[1;33m>>> %s\033[0m\n' "$*" >&2; }

# Wait for a Cloud Build with a progress line, then print the lines that matter
# (findings by severity, GATE/SIGNED verdicts). Returns non-zero unless SUCCESS.
wait_build() {
  local id=$1 status
  printf '    cloud build %s ' "${id:0:8}" >&2
  while :; do
    status=$(gcloud builds describe "$id" --format='value(status)')
    case "$status" in QUEUED|WORKING|PENDING) printf '.' >&2; sleep 10 ;; *) break ;; esac
  done
  printf ' %s\n' "$status" >&2
  sleep 5
  gcloud logging read "resource.type=build AND resource.labels.build_id=$id" \
      --limit=300 --format='value(textPayload)' 2>/dev/null | tac \
    | grep -E 'findings by severity|"(gate|verify-and-sign)": +[0-9]+ [A-Z]+$|GATE|SIGNED|REFUSING' \
    | sed -E 's/^Step #[0-9]+ - "[a-z-]+": /      /' >&2
  [[ "$status" == "SUCCESS" ]]
}

# ship DOCKERFILE REQS FAIL_ON APP_TAG
# Stage 1 (build, scan, gate, push) then stage 2 (re-scan digest, sign, tag).
# Prints the signed image reference (image@sha256:...) on the last line.
ship() {
  local dockerfile=$1 reqs=$2 fail_on=$3 app_tag=$4 id id2 digest
  say "stage 1: build + scan + gate  ($dockerfile, $reqs, fail on $fail_on)"
  id=$(cd "$ROOT" && gcloud builds submit --config cloudbuild.yaml --async \
        --format='value(id)' \
        --substitutions="_DOCKERFILE=${dockerfile},_REQS=${reqs},_FAIL_ON=${fail_on}" . 2>/dev/null)
  wait_build "$id" || { say "BLOCKED at the build gate: never pushed, never signed"; return 1; }

  say "stage 2: re-scan the pushed digest + sign"
  id2=$(cd "$ROOT" && gcloud builds submit --no-source --config cloudbuild-attest.yaml \
        --async --format='value(id)' \
        --substitutions="_TAG=${id},_APP_TAG=${app_tag},_FAIL_ON=${fail_on}" 2>/dev/null)
  wait_build "$id2" || { say "signer refused"; return 1; }

  digest=$(gcloud artifacts docker images describe "${IMAGE}:${id}" \
            --format='value(image_summary.digest)')
  echo "${IMAGE}@${digest}" | tee "$ROOT/out/${app_tag}-ref.txt"
}

running_ref() {
  kubectl get deploy cve-demo -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null
}
