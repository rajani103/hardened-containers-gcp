# Lessons learned (things that broke on the first real run)

## 1. Docker Hardened Images use zstd-compressed layers

**Symptom:** Cloud Build's default `docker build` failed with
`failed to register layer: ... archive/tar: invalid tar header`.

**Cause:** DHI layers are `application/vnd.oci.image.layer.v1.tar+zstd`. The Docker daemon on Cloud Build's default workers can't unpack zstd. The images were fine; `crane validate` also complained, because it assumes gzip.

**Fix:** build with BuildKit (docker-container driver), which reads zstd, and export gzip back to the daemon:

```bash
docker buildx create --driver docker-container --use
docker buildx build --output type=docker,compression=gzip,force-compression=true ...
```

## 2. The scanner may not see everything

Artifact Analysis reports **`Missing os-release file`** for the hardened image, so it may only be scanning language packages (Python) there, not OS packages. Part of "400 → near zero" can be the scanner seeing less, not only the image containing less.

**Takeaway:** "zero CVEs" means "zero findings this scanner can see". Cross-check with a second scanner before publishing numbers.

## 3. Provenance needs `images:`, not `docker push`

The `built-by-cloud-build` attestation is written only when Cloud Build pushes the image itself via the `images:` field. An explicit `docker push` step produces no provenance. That's why the pipeline has two stages.

## 4. IAM for a custom build service account

A dedicated build service account needs more than you'd expect:

- `roles/storage.objectViewer` to read its own uploaded source tarball;
- repo-level `roles/artifactregistry.repoAdmin` to **move** an existing tag (`writer` can create tags, not update or delete them).

## 5. GKE shielded node flags come in pairs

`--shielded-secure-boot` on its own fails; pass `--shielded-integrity-monitoring` too.

## 6. Pushing from Cloud Shell's Docker daemon is flaky

Repeated `connection refused` errors from Cloud Shell's Docker daemon to Artifact Registry, while `curl` from the same shell worked. Copying registry to registry with `crane` avoided the daemon entirely and was faster.

## 7. `gcloud logging read` defaults to the last day

Reading Cloud Build logs older than 24h returns nothing unless you pass `--freshness=7d` (or similar).

## 8. Drop the Pub/Sub backlog before a demo

A long-lived subscription on `container-analysis-occurrences-v1` accumulates every occurrence. Seek to "now" before starting the bot:

```bash
gcloud pubsub subscriptions seek cve-bot --time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```
