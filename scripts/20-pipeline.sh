#!/usr/bin/env bash
# DEMO 2a: both Dockerfiles through the same two-stage pipeline.
#   hardened (v1 deps) -> gate passes -> pushed by Cloud Build -> re-scanned -> signed -> tag "prod"
#   old base           -> gate fails  -> never pushed, never signed
# Takes several minutes (two Cloud Builds per image).
set -euo pipefail
source "$(dirname "$0")/lib.sh"

say "hardened image, yesterday's dependencies (gate: CRITICAL)"
ship Dockerfile.dhi requirements-v1.txt CRITICAL prod

say "old base image, same pipeline (expected to FAIL at the gate)"
ship Dockerfile.before requirements.txt CRITICAL before || say "blocked, as designed"
