# Interview tasks

## Task 1

You've been given a small script that's supposed to run in CI, but it's unreliable. Fix the script, then wrap it in a CI pipeline.

**Your task**
Fix `check-logs.sh` file bellow - so that it:

1. Runs under `set -euo pipefail`.
2. Takes a directory as its first argument (default to `.`), and searches `.log` files  recursively inside it.
3. Prints the number of `ERROR` lines found.
4. Exits non-zero if one or more `ERROR` lines are found, `0` otherwise.
5. Does not crash when there are no `.log` files at all (it should report `0` and exit `0`).

Create a CI pipeline (GitHub Actions `*.yml` *or* a `Jenkinsfile` — candidate's choice) that makes foolowing steps:

1. Checks out the repo - (first create one on GitHub).
2. Makes the script executable and runs `./check-logs.sh ./logs`.
3. Uploads the script's output as a build artifact / archived file to Github Action  or Jenkins.
4. The pipeline status reflects the script  — it goes red when `ERROR` lines exist.

check-logs.sh:

```bash
#!/bin/bash
# Counts ERROR lines in all .log files and fails if any are found.

grep ERROR *.log | wc -l
echo "Done"
```

## Task 2

Below is a working `Jenkinsfile` already in use by a team. It builds an artifact and publishes a report. Your job is to extend and fix it — not to rewrite it. Keep the existing structure and style.

**Your task**
Modify the pipeline file  bellow so that:

1. Add a parameter `DEPLOY_ENV` (choice: `dev`, `staging`, `prod`; default `dev`) and echo the chosen environment in the `Prepare` stage.
2. Add a `Test` stage between `Package` and `Report` that:
    1. prints `out/version.txt` content to the log, and
    2. fails the build if the file is empty.
3. Add a conditional `Deploy` stage that runs only when `DEPLOY_ENV == 'prod'`, and only on the `main` branch. It just needs to `echo` a deploy message (no real deploy).
4. Archive the artifact and publish `out/version.txt`, using a `post` section so it happens even if a later stage fails.
5. Fix the latent bug: the current pipeline leaves `out/` and old `*.tar.gz` behind between runs on the same agent. Ensure each run starts clean.

```groovy
pipeline {
   agent any

    environment {
        ARTIFACT = "app-${BUILD_NUMBER}.tar.gz"
    }

    stages {
        stage('Prepare') {
            steps {
                sh 'mkdir -p out'
                sh 'echo "version=1.0.${BUILD_NUMBER}" > out/version.txt'
            }
        }

        stage('Package') {
            steps {
                sh 'tar czf ${ARTIFACT} out/'
            }
        }

        stage('Report') {
            steps {
                sh 'echo "Packaged ${ARTIFACT}"'
            }
        }
    }
}
```

## Task 3: repair the Dockerfile

Create the starter files below for a small Python HTTP application. The starter Dockerfile does not produce a working application. Diagnose and repair it.

**Your task**
Find and fix bugs in commands, filles bellow.
Deliver your edited files and demonstrate the commands you used. Correctness and a clear diagnosis matter more than optional optimizations.
Explain the problems you found and your changes in given files.

### Prepare the environment

1. Install Docker and start its daemon, or use an already-running Podman engine. You also need Bash, curl, and internet access for the Python base image.

2. Open a Bash terminal in the directory containing this README. Check the tools:

```bash
docker version
docker info
docker pull docker.io/library/python:3.12-alpine
curl --version
```

If using Podman, replace `docker` with `podman` throughout this exercise.

3. Create a fresh working directory:

```bash
mkdir work
cd work
```

4. Create these three files by running the following commands in that directory. Use a fresh directory so the commands do not overwrite previous work.

#### `app.py`

```bash
cat > app.py <<'PY'
"""Small dependency-free HTTP application for the interview exercises."""

import json
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthz":
            self.respond(200, b"ok\n", "text/plain")
        elif self.path == "/":
            body = json.dumps(
                {
                    "message": os.environ.get(
                        "APP_MESSAGE", "Hello from the interview app"
                    ),
                    "hostname": socket.gethostname(),
                }
            ).encode() + b"\n"
            self.respond(200, body, "application/json")
        else:
            self.respond(404, b"not found\n", "text/plain")

    def respond(self, status, body, content_type):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    print(f"Listening on 0.0.0.0:{port}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
PY
```

#### `Dockerfile`

This is the intentionally broken starting point. Create it exactly as shown, then diagnose it during the exercise.

```bash
cat > Dockerfile <<'DOCKERFILE'
FROM docker.io/library/python:3.12-alpine
WORKDIR /app
COPY server.py /srv/app.py
EXPOSE 8080
CMD ["python", "server.py"]
DOCKERFILE
```

#### `.dockerignore`

```bash
cat > .dockerignore <<'IGNORE'
__pycache__/
*.pyc
.git/
README.md
IGNORE
```

### Requirements

1. Build an image tagged `interview-docker:candidate`.
2. Run it as `interview-docker-candidate`.
3. Make it reachable at `http://127.0.0.1:18080`.
4. Successful request to `/` and `/healthz`.

The application listens on port **8080** inside the container. It uses Python's standard library and needs no pip packages. Do not modify `app.py`.

### Build, run, and verify

Inspect and edit the Dockerfile in `work/`, then use these commands from that same directory:

```bash
docker build -t interview-docker:candidate .
docker run -d --name interview-docker-candidate \
  -p 127.0.0.1:18080:8080 interview-docker:candidate
curl -fsS http://127.0.0.1:18080/
curl -fsS http://127.0.0.1:18080/healthz
```

If a failed container already uses the name, inspect its logs and remove it before retrying:

```bash
docker logs interview-docker-candidate
docker rm -f interview-docker-candidate
```

### Cleanup

```bash
docker rm -f interview-docker-candidate
docker image rm interview-docker:candidate
```

## Task 4: repair a Deployment and Service

Complete the task independently on your own machine. No interviewer observes setup, diagnosis, or verification in real time. Submit the files and evidence listed below for later review.

**Your task**
Find and fix bugs in commands, filles bellow.
Prepare your own local kind cluster and deploy the supplied Python HTTP application using the steps below. The starter Deployment and Service contain deliberate faults: the pods are unhealthy, and `web` cannot serve HTTP requests.

Create `deployment.yaml` and `service.yaml` from the starter commands below. Inspect the running resources, diagnose the problems, repair those files, and apply your fixes.

As result deliver files:
- `deployment.yaml`: your corrected Deployment.
- `service.yaml`: your corrected Service.
- `verify.sh`: the supplied verification script.
- `verification.txt`: the complete successful verification output.
- `REPORT.md`: your completed explanation and diagnostic evidence.

### Environment

- Context: `kind-docker-k8s-interview`
- Namespace: `interview`
- Deployment and Service: `web`
- Image: `localhost/docker-k8s-interview-app:1.0`, built and loaded during setup
- Application port: **8080**

- Required Service port: **80**

- Required replicas: **2**

- Application endpoints: `/` returns JSON; `/healthz` returns `ok`

### Prepare the environment

You create the cluster yourself; no cluster or kubeconfig is supplied by the interviewer. Complete steps 1–9 before diagnosing the faults. The suggested actions covers diagnosis and repair; verification, and packaging. Keep using the same Bash terminal and working directory throughout setup.

#### 1. Install and check the tools

Install [Docker](https://docs.docker.com/get-started/get-docker/), [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation), and [kubectl](https://kubernetes.io/docs/tasks/tools/). Start Docker Desktop or the Docker daemon. You also need Bash, curl, internet access for the initial image pulls, and around 4 CPUs and 6 GB of available container-engine memory.
Use kubectl within one minor version of the Kubernetes version used by kind.

On  Linux, WSL(Windows), MacOS depends what system you have instal kind and kubectl:

Check that all tools are available and that the container engine is running:

```bash
docker version
docker info
kind version
kubectl version --client
curl --version
```

The instructions use Docker. If using an already-running rootful Podman engine, read the **Podman alternative** below and make those substitutions from the start.

#### 2. Create a fresh working directory

Open a Bash terminal in the directory containing this README:

```bash
mkdir work
cd work
export KIND_EXPERIMENTAL_PROVIDER=docker
kind get clusters
mkdir setup
mkdir -m 700 .runtime
```

Check that `kind get clusters` does not list `docker-k8s-interview`. If that name already exists, use a fresh environment rather than another person's cluster. All following files and commands are relative to `work/`.

#### 3. Create the application and image build files

This dependency-free application and working Dockerfile prepare the image for the Kubernetes exercise. Keep these files unchanged during diagnosis.

```bash
cat > setup/app.py <<'PY'
"""Small dependency-free HTTP application for the interview exercises."""

import json
import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/healthz":
            self.respond(200, b"ok\n", "text/plain")
        elif self.path == "/":
            body = json.dumps(
                {
                    "message": os.environ.get(
                        "APP_MESSAGE", "Hello from the interview app"
                    ),
                    "hostname": socket.gethostname(),
                }
            ).encode() + b"\n"
            self.respond(200, body, "application/json")
        else:
            self.respond(404, b"not found\n", "text/plain")

    def respond(self, status, body, content_type):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    print(f"Listening on 0.0.0.0:{port}", flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
PY

cat > setup/Dockerfile <<'DOCKERFILE'
FROM docker.io/library/python:3.12-alpine
WORKDIR /app
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 PORT=8080
COPY app.py .
USER 10001:10001
EXPOSE 8080
CMD ["python", "app.py"]
DOCKERFILE
```

#### 4. Build the application image

```bash
docker build -t localhost/docker-k8s-interview-app:1.0 setup
docker image inspect localhost/docker-k8s-interview-app:1.0 --format '{{.Id}}'
```

The build must succeed before continuing. No pip packages are needed.

#### 5. Create the kind configuration and cluster

Create a configuration for one control-plane node with its API bound to localhost:

```bash
cat > setup/kind.yaml <<'YAML'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "127.0.0.1"
nodes:
  - role: control-plane
YAML
```

Create the cluster. kind runs the node as a container and writes the cluster credentials to a dedicated kubeconfig:

```bash
kind create cluster --name docker-k8s-interview \
  --config setup/kind.yaml --kubeconfig .runtime/kubeconfig --wait 120s
```

The cluster name produces the context `kind-docker-k8s-interview`. Optionally add `--image kindest/node:YOUR_SUPPORTED_VERSION` to this command to choose a node image supported by your installed kind version.

#### 6. Select the kubeconfig and check node readiness

```bash
chmod 600 .runtime/kubeconfig
export KUBECONFIG="$PWD/.runtime/kubeconfig"
kubectl config get-contexts
kubectl --context kind-docker-k8s-interview \
  wait --for=condition=Ready nodes --all --timeout=120s
kubectl --context kind-docker-k8s-interview get nodes
```

The node should report `Ready`. This dedicated kubeconfig keeps the exercise separate from your default Kubernetes configuration. If you open another Bash terminal, export the same absolute `KUBECONFIG` path there.

#### 7. Load the application image into kind

The host's image store and the kind node's image store are separate. Export the image and import it into the named cluster:

```bash
docker save -o .runtime/app-image.tar localhost/docker-k8s-interview-app:1.0
kind load image-archive .runtime/app-image.tar --name docker-k8s-interview
```

The tag must match the Deployment exactly. Its `imagePullPolicy: Never` uses the loaded image; no registry server is needed.

#### 8. Create the exercise namespace

```bash
kubectl --context kind-docker-k8s-interview create namespace interview
kubectl --context kind-docker-k8s-interview get namespace interview
```

Next, create and apply the starter manifests in step 9 below.

#### Podman alternative

For an already-running **rootful** Podman engine, replace the Docker version, info, build, and image-inspection commands with their `podman` equivalents. Set `KIND_EXPERIMENTAL_PROVIDER=podman` before any kind commands, and replace `docker save` with:

```bash
podman save --format docker-archive -o .runtime/app-image.tar \
  localhost/docker-k8s-interview-app:1.0
```

Keep the same `kind create cluster` and `kind load image-archive` commands. Podman uses kind's experimental Podman provider.

### 9. Create and deploy the starter manifests

Run both commands from `work/`. These manifests contain deliberate faults; copy them exactly before diagnosing the problems.

#### `deployment.yaml`

```bash
cat > deployment.yaml <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: interview
spec:
  replicas: 2
  selector:
    matchLabels:
      app: interview-web
  template:
    metadata:
      labels:
        app: interview-web
    spec:
      containers:
        - name: web
          image: localhost/docker-k8s-interview-app:1.0
          imagePullPolicy: Never
          command: ["python", "/app/missing.py"]
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: APP_MESSAGE
              value: Hello from Kubernetes
          readinessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 2
            periodSeconds: 3
          livenessProbe:
            httpGet:
              path: /healthz
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            requests:
              cpu: 50m
              memory: 32Mi
            limits:
              cpu: 250m
              memory: 64Mi
          securityContext:
            allowPrivilegeEscalation: false
            runAsNonRoot: true
            runAsUser: 10001
            capabilities:
              drop: ["ALL"]
YAML
```

#### `service.yaml`

```bash
cat > service.yaml <<'YAML'
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: interview
spec:
  type: ClusterIP
  selector:
    app: interview-api
  ports:
    - name: http
      port: 80
      targetPort: 9090
YAML
```

Install the broken starting resources:

```bash
kubectl --context kind-docker-k8s-interview -n interview \
  apply -f deployment.yaml -f service.yaml
kubectl --context kind-docker-k8s-interview -n interview get pods,deploy,svc
```

Both resources should exist. Pods may initially show `ContainerCreating`, then `Error` or `CrashLoopBackOff`; unhealthy pods are expected. Begin diagnosis once the cluster, loaded image, namespace, and starter resources are in place.

### Requirements

1. Identify why the application containers fail.
2. Make both replicas healthy and ready.
3. Make the Service route HTTP traffic to the application.
4. Keep the image built during setup, two replicas, and Service port 80.
5. Save all fixes in the created YAML files and submit verification evidence and a written explanation of the causes.
Do not replace kind, edit the application image, or recreate the cluster. The namespace is disposable. Other clusters and namespaces are outside scope.
Useful resources include pod descriptions, logs, labels, Service configuration, and EndpointSlices. Apply your edits with:

```bash
kubectl --context kind-docker-k8s-interview -n interview \
  apply -f deployment.yaml -f service.yaml
```

### Verify your fixes

Run all checks yourself and save the results before cleanup. Both replicas must be ready, and requests must succeed through the Service's cluster DNS name. Port forwarding alone does not prove ClusterIP connectivity.

Create `verify.sh` in `work/` using this command. The script records tool and resource information, checks the required replicas, image, and Service port, and runs HTTP checks from a temporary pod. Keep its checks unchanged.

```bash
cat > verify.sh <<'VERIFY'
#!/usr/bin/env bash
set -euo pipefail
: "${KUBECONFIG:?Export the kubeconfig path from setup step 6 first.}"

k() {
  kubectl --context kind-docker-k8s-interview -n interview "$@"
}

probe="interview-http-check-$$"
cleanup() {
  k delete pod "$probe" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

printf '=== Tool versions and node readiness ===\n'
kind version
kubectl version --client
kubectl --context kind-docker-k8s-interview \
  wait --for=condition=Ready nodes --all --timeout=120s
kubectl --context kind-docker-k8s-interview get nodes -o wide

printf '\n=== Deployment, pods, Service, and EndpointSlices ===\n'
k rollout status deployment/web --timeout=120s
k get deployment web -o yaml
k get pods --show-labels
k get service web -o yaml
k get endpointslices -l kubernetes.io/service-name=web -o yaml

replicas="$(k get deployment web -o jsonpath='{.spec.replicas} {.status.readyReplicas}')"
[[ "$replicas" == "2 2" ]] \
  || { printf 'FAIL: expected two desired and two ready replicas.\n' >&2; exit 1; }

image="$(k get deployment web -o jsonpath='{.spec.template.spec.containers[?(@.name=="web")].image}')"
[[ "$image" == "localhost/docker-k8s-interview-app:1.0" ]] \
  || { printf 'FAIL: keep the application image built during setup.\n' >&2; exit 1; }

service_port="$(k get service web -o jsonpath='{.spec.ports[?(@.port==80)].port}')"
[[ "$service_port" == 80 ]] \
  || { printf 'FAIL: the Service must expose port 80.\n' >&2; exit 1; }

printf '\n=== HTTP through web.interview.svc.cluster.local:80 ===\n'
k run "$probe" --image localhost/docker-k8s-interview-app:1.0 \
  --image-pull-policy=Never --restart=Never \
  --command -- python -c '
import json
from urllib.request import urlopen
base = "http://web.interview.svc.cluster.local:80"
with urlopen(base + "/healthz", timeout=10) as response:
    body = response.read().strip()
    assert response.status == 200 and body == b"ok"
    print("/healthz: HTTP", response.status, body.decode())
with urlopen(base + "/", timeout=10) as response:
    data = json.load(response)
    assert response.status == 200 and data["message"] == "Hello from Kubernetes"
    assert data["hostname"]
    print("/: HTTP", response.status, json.dumps(data))
print("Service HTTP checks passed.")
'
if ! k wait --for=jsonpath='{.status.phase}'=Succeeded \
  "pod/$probe" --timeout=60s; then
  k logs "$probe" >&2 || true
  printf 'FAIL: in-cluster HTTP verification did not succeed.\n' >&2
  exit 1
fi
k logs "$probe"
printf '\nVERIFICATION PASSED\n'
VERIFY
```

Run it and save both standard output and errors:

```bash
bash verify.sh > verification.txt 2>&1
cat verification.txt
```

The script must exit successfully and the log must end with `VERIFICATION PASSED`. If a check fails, inspect the log, diagnose the problem, update your manifests, apply them, and rerun the script. Submit the complete successful log without editing it.

You may also inspect HTTP responses from your host. Run this in one terminal:

```bash
kubectl --context kind-docker-k8s-interview -n interview \
  port-forward service/web 18081:80
```

In another terminal:

```bash
curl -fsS http://127.0.0.1:18081/
curl -fsS http://127.0.0.1:18081/healthz
```

### Prepare your submission

Create `REPORT.md` and fill in the template with your actual observations. Include the diagnostic commands and relevant output that identified each cause, what you changed, and how the saved verification demonstrates the fix.

```bash
cat > REPORT.md <<'REPORT'
# Kubernetes task report

## Environment
- Operating system and architecture:
- Container engine and version:
- kind version:
- Kubernetes and kubectl versions:

## Diagnosis and changes
For each problem, describe:
- Observed symptom.
- Diagnostic command and relevant output.
- Root cause.
- Manifest change and why it resolves the problem.

## Verification
- Commands used to apply the corrected manifests:
- Results for replica readiness and Service connectivity:
- How the in-cluster HTTP check verifies traffic through the Service:
- Successful verification log: verification.txt

## Effort and remaining issues
- Approximate setup, diagnosis, and verification time:
- Any remaining issues or incomplete checks:
REPORT
```

Package them from `work/`:

```bash
mkdir submission
cp deployment.yaml service.yaml verify.sh verification.txt REPORT.md submission/
tar -czf submission.tar.gz -C submission .
tar -tzf submission.tar.gz
```

Send `submission.tar.gz` through the submission channel specified in the task invitation. Submit only these five files; keep `.runtime/`, kubeconfig, and image archives on your machine. The reviewer assesses the submission later and can reproduce it in their own cluster.

### Cleanup

After saving the successful verification output and creating your submission, stop any port forwarding with Ctrl+C and remove the dedicated cluster. You can clean up immediately; no live review or approval is required.

```bash
kind delete cluster --name docker-k8s-interview --kubeconfig .runtime/kubeconfig
docker image rm localhost/docker-k8s-interview-app:1.0
```

In Podman mode, use `podman image rm`. Keep the corrected manifests as your submission.

### Setup troubleshooting
- Docker connection error: start Docker Desktop or the Docker daemon, then rerun `docker info`.
- Cluster name already exists: check `kind get clusters` and use a fresh environment. Delete an old exercise cluster only if it belongs to you.
- kind startup failure: check available memory and collect logs with `kind export logs .runtime/kind-logs --name docker-k8s-interview`.
- `ErrImageNeverPull`: repeat step 7 and confirm the image tag matches exactly.
- kubectl connection error: re-export the absolute kubeconfig path from step 6 and confirm the context.
- Port 18081 occupied: free it or use another local port, updating your curl URLs.
