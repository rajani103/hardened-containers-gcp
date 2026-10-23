# Walkthrough: every step and command

## Setup

### Project and APIs (`scripts/00-setup.sh`)

```bash
gcloud services enable container artifactregistry cloudbuild containeranalysis \
  containerscanning ondemandscanning binaryauthorization cloudkms pubsub   # .googleapis.com
gcloud artifacts repositories create demo     --repository-format=docker --location=asia-south1
gcloud artifacts repositories create hardened --repository-format=docker --location=asia-south1
gcloud iam service-accounts create cve-demo-builder
# + the role bindings listed in ARCHITECTURE.md
```

A dedicated, least-privilege service account runs every Cloud Build, instead of the default compute account.

### Mirror the hardened base (`scripts/01-mirror-base.sh`)

```bash
docker login dhi.io
crane copy --platform linux/amd64 dhi.io/python:3.13-alpine3.23-dev $BASE_REGISTRY/python:3.13-alpine3.23-dev
crane copy --platform linux/amd64 dhi.io/python:3.13-alpine3.23     $BASE_REGISTRY/python:3.13-alpine3.23
```

CI builds from your own registry: no external logins or rate limits, and you control which base digests come in.

### Signing key, attestor, policy (`scripts/02-binauthz.sh`)

```bash
gcloud kms keyrings create binauthz --location=asia-south1
gcloud kms keys create vulnz-signer --keyring=binauthz --location=asia-south1 \
  --purpose=asymmetric-signing --default-algorithm=ec-sign-p256-sha256
# Container Analysis note "vulnz-note" via REST
gcloud container binauthz attestors create vulnz-attestor --attestation-authority-note=vulnz-note ...
gcloud beta container binauthz attestors public-keys add --attestor=vulnz-attestor --keyversion-key=vulnz-signer ...
gcloud container binauthz policy import policy.yaml
```

### Cluster (`scripts/03-cluster.sh`)

```bash
gcloud container clusters create cve-demo --zone=asia-south1-a --num-nodes=2 \
  --machine-type=e2-standard-2 \
  --binauthz-evaluation-mode=PROJECT_SINGLETON_POLICY_ENFORCE \
  --shielded-secure-boot --shielded-integrity-monitoring
```

## Act 1: same code, two bases (`scripts/10-demo1-scan.sh`)

```bash
docker build -f Dockerfile.before -t app:before .
docker build -f Dockerfile.dhi    -t app:dhi .
gcloud artifacts docker images scan app:before --location=asia --format='value(response.scan)'
gcloud artifacts docker images list-vulnerabilities <scan> --format='value(vulnerability.effectiveSeverity)'
docker run --rm --entrypoint sh app:dhi    # fails: there is no shell
```

## Act 2: the pipeline (`scripts/20-pipeline.sh`)

Stage 1 (`cloudbuild.yaml`):

```bash
docker buildx create --driver docker-container --use
docker buildx build --output type=docker,compression=gzip,force-compression=true \
  -f Dockerfile.dhi --build-arg BASE_REGISTRY=... -t app:$BUILD_ID .
gcloud artifacts docker images scan app:$BUILD_ID --location=asia
gcloud artifacts docker images list-vulnerabilities $SCAN ... | grep CRITICAL && exit 1
# images: [app:$BUILD_ID]   → Cloud Build pushes and writes provenance
```

Stage 2 (`cloudbuild-attest.yaml`):

```bash
gcloud artifacts docker images scan app@sha256:... --remote --location=asia
gcloud beta container binauthz attestations sign-and-create --artifact-url=app@sha256:... \
  --attestor=vulnz-attestor --keyversion-key=vulnz-signer ...
gcloud artifacts docker tags add app:$BUILD_ID app:prod
```

Result from the real run:

```
python:3.13 (old base)
        8 CRITICAL
       53 HIGH
      191 LOW
      173 MEDIUM
      627 MINIMAL
    GATE FAILED: found CRITICAL. Image will not be pushed.
Docker Hardened Image
        2 HIGH
        2 LOW
    GATE PASSED
SIGNED: .../demo/app@sha256:1d18b198...
```

Then `scripts/04-policy-strict.sh` switches the policy to require both attestors.

## Act 3: deploy the signed image (`scripts/22-deploy-signed.sh`)

```bash
envsubst < k8s/deployment.yaml | kubectl apply -f -      # image: app@sha256:...
kubectl rollout status deploy/cve-demo
curl localhost:8080/
# {"app":"cve-demo","base_image":"dhi/python:3.13-alpine3.23","python":"3.13.16","uid":65532}
kubectl exec deploy/cve-demo -- sh
# exec: "sh": executable file not found in $PATH
```

## Act 4: bypass #1, skip CI (`scripts/21-bypass.sh`)

```bash
crane copy docker.io/library/python:3.13-slim $IMAGE:bypass
kubectl run bypass --image=$IMAGE@sha256:...
# denied by attestor built-by-cloud-build: No attestations found
# denied by attestor vulnz-attestor: No attestations found
```

## Act 5: bypass #2, the real key (`scripts/21b-laptop-signed.sh`)

```bash
crane copy $BASE_REGISTRY/python:3.13-alpine3.23 $IMAGE:laptop
gcloud beta container binauthz attestations sign-and-create --artifact-url=$IMAGE@sha256:... \
  --attestor=vulnz-attestor ...          # signed with the real KMS key
kubectl run laptop --image=$IMAGE@sha256:...
# denied by attestor built-by-cloud-build: No attestations found
```

A leaked signing key is not enough: the image still has no pipeline provenance.

## Act 6: self-healing (`scripts/30-cve-bot.sh`, `scripts/31-simulate-cve.sh`)

```bash
gcloud pubsub subscriptions create cve-bot --topic=container-analysis-occurrences-v1
./scripts/30-cve-bot.sh &
# find a real HIGH/CRITICAL occurrence on the running digest, re-publish its notification
./scripts/31-simulate-cve.sh
```

Real run:

```
>>> ALERT  CVE-2024-6827  HIGH  in gunicorn  on the RUNNING image
>>> stage 1: build + scan + gate  (Dockerfile.dhi, requirements.txt, fail on CRITICAL|HIGH)
    build ...: SUCCESS
>>> stage 2: re-scan the pushed digest + sign
    build ...: SUCCESS
>>> rolling out .../demo/app@sha256:2a0316f3...
deployment "cve-demo" successfully rolled out
>>> HEALED. CVE-2024-6827 is gone from production.
  · CVE-2025-47278 LOW on the running image. below threshold, log only.
```

## Optional: break glass (`scripts/23-breakglass.sh`)

```bash
kubectl run breakglass --image=<unsigned> --annotations="alpha.image-policy.k8s.io/break-glass=true"
```

The pod runs, and the override is recorded in Cloud Audit Logs.
