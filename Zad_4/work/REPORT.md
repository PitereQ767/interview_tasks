# Kubernetes Repair Report

## Environment

I used Docker, kind and kubectl on Linux. I created a local kind cluster named
`docker-k8s-interview` and used the `kind-docker-k8s-interview` context.

The application image was built and loaded into the cluster with these commands:

```bash
docker build -t localhost/docker-k8s-interview-app:1.0 setup
docker save -o .runtime/app-image.tar localhost/docker-k8s-interview-app:1.0
kind load image-archive .runtime/app-image.tar --name docker-k8s-interview
```

I created the `interview` namespace and applied the starter manifests:

```bash
kubectl --context kind-docker-k8s-interview create namespace interview
kubectl --context kind-docker-k8s-interview -n interview \
  apply -f deployment.yaml -f service.yaml
```

## Initial Problems

After applying the starter files, the pods entered `CrashLoopBackOff`. The
Service also had no endpoints and could not send HTTP traffic to the application.

I used the following commands to inspect the resources:

```bash
kubectl --context kind-docker-k8s-interview -n interview get pods,deploy,svc
kubectl --context kind-docker-k8s-interview -n interview describe pod <pod-name>
kubectl --context kind-docker-k8s-interview -n interview logs <pod-name>
kubectl --context kind-docker-k8s-interview -n interview describe service web
kubectl --context kind-docker-k8s-interview -n interview get pods --show-labels
```

## Problems Found and Fixes

### 1. Wrong application file

The Deployment tried to start `/app/missing.py`. The container logs showed:

```text
python: can't open file '/app/missing.py': [Errno 2] No such file or directory
```

The image contains `/app/app.py`, so I changed the container command to:

```yaml
command: ["python", "/app/app.py"]
```

After applying the Deployment again, I checked the rollout and pod status:

```bash
kubectl --context kind-docker-k8s-interview -n interview apply -f deployment.yaml
kubectl --context kind-docker-k8s-interview -n interview \
  rollout status deployment/web
kubectl --context kind-docker-k8s-interview -n interview get pods
```

### 2. Service selector did not match the pods

The Service used the selector `app: interview-api`, but the pods had the label
`app: interview-web`. Because of this, the Service had no endpoints.

I changed the Service selector to:

```yaml
selector:
  app: interview-web
```

### 3. Wrong Service target port

The Service used `targetPort: 9090`, but the application listens on port `8080`.
I changed the Service configuration to route port 80 to port 8080:

```yaml
ports:
  - name: http
    port: 80
    targetPort: 8080
```

## Verification

I ran the supplied verification script and saved all output:

```bash
bash verify.sh > verification.txt 2>&1
```

The verification confirmed that:

- the kind node was ready;
- the Deployment rollout completed successfully;
- two replicas were requested and both were ready;
- both pods were running without restarts;
- the Service exposed port 80;
- the EndpointSlice contained both ready pods on port 8080;
- `/healthz` returned HTTP 200 and `ok`;
- `/` returned HTTP 200 and the expected JSON message.

The script finished with:

```text
VERIFICATION PASSED
```

I also tested the Service from the host using port forwarding:

```bash
kubectl --context kind-docker-k8s-interview -n interview \
  port-forward service/web 18081:80

curl -fsS http://127.0.0.1:18081/
curl -fsS http://127.0.0.1:18081/healthz
```

The root endpoint returned the expected `Hello from Kubernetes` JSON response,
and the health endpoint returned `ok`.

## Conclusion

The repaired Deployment runs two healthy application pods. The Service selects
both pods and routes HTTP traffic from port 80 to the application on port 8080.
The complete successful verification output is available in `verification.txt`.
