# CS411 Final Exam

Sample Express service for the CS411 DevOps final exam. The app listens on port `4444` and returns a small JSON payload from `/`.

## Application

Requirements:

- Node.js `>=24`
- npm

Run locally:

```bash
npm install
npm test
npm start
```

Check the app:

```bash
curl http://localhost:4444/
```

Expected response:

```json
{"name":"Hello","description":"World","url":"localhost:4444"}
```

## Docker

The `Dockerfile` uses a multi-stage build:

- `base`: installs dependencies and copies source.
- `test`: runs `npm test`.
- `prod`: prunes dev dependencies and runs the app.

Build the test target:

```bash
docker build --target test -t ttl.sh/albertolg101:2h-test .
```

Build the production image:

```bash
docker build --target prod -t ttl.sh/albertolg101:2h .
```

Run with Docker:

```bash
docker run --rm -p 4444:4444 ttl.sh/albertolg101:2h
```

The production image includes a Docker health check for `http://localhost:4444/`.

## Docker Compose

Run the local `myapp` service:

```bash
docker compose up -d --build myapp
```

Stop it:

```bash
docker compose down
```

## Jenkins Pipeline

`Jenkinsfile` defines this flow:

1. `Test`: builds the Docker `test` target.
2. `Build`: builds the Docker `prod` target.
3. `Push`: pushes `ttl.sh/albertolg101:2h`.
4. `Deploy`: deploys to the Docker host with `docker-playbook.yml`.
5. `Deploy: Target`: deploys as a systemd service with `target-playbook.yml`.
6. `Deploy: Kubernetes`: deploys `k8s/pod.yaml` and `k8s/service.yaml`.

Required Jenkins credentials:

- `docker-ssh-key`: SSH key and username for the Docker deploy host.
- `target-ssh-key`: SSH key and username for the systemd target host.
- `k8s-token`: Kubernetes API token for the Kubernetes deploy stage.

Pipeline hosts and image:

- Docker host: `docker`
- Target host: `target`
- Kubernetes API server: `https://kubernetes:6443`
- Image: `ttl.sh/albertolg101:2h`

### Running the Pipeline

Before running the Jenkins job, make sure the Jenkins agent has:

- Docker installed and access to the Docker daemon.
- Ansible installed.
- `kubectl` installed.
- Network access to the `docker`, `target`, and `kubernetes` hosts.
- The Jenkins credentials listed above.

Run the pipeline from Jenkins:

1. Create or open a Pipeline job.
2. Configure it to use this repository and the `Jenkinsfile` from the repo root.
3. Start the job with `Build Now`.
4. Watch the stages in order: `Test`, `Build`, `Push`, `Deploy`, `Deploy: Target`, and `Deploy: Kubernetes`.

The pipeline should fail automatically if:

- The Docker test target fails.
- The production image cannot be built or pushed.
- The Docker host deployment health check does not return HTTP `200`.
- The target host systemd deployment health check does not return HTTP `200`.
- The Kubernetes pod does not become `Ready` within `120s`.

### Verifying Deployment

After the Jenkins pipeline finishes successfully, verify each deployment target.

Verify the Docker host:

```bash
ssh <docker-user>@docker 'docker ps --filter name=albertolg101'
ssh <docker-user>@docker 'curl -f http://127.0.0.1:4444/'
```

Verify the target systemd host:

```bash
ssh <target-user>@target 'systemctl status myapp --no-pager'
ssh <target-user>@target 'curl -f http://127.0.0.1:4444/'
```

Verify Kubernetes:

```bash
kubectl --server=https://kubernetes:6443 --insecure-skip-tls-verify=true --token="$K8S_TOKEN" get pod myapp
kubectl --server=https://kubernetes:6443 --insecure-skip-tls-verify=true --token="$K8S_TOKEN" get service myapp
kubectl --server=https://kubernetes:6443 --insecure-skip-tls-verify=true --token="$K8S_TOKEN" wait --for=condition=Ready pod/myapp --timeout=120s
```

The Kubernetes Service is exposed as a NodePort on `30444`, so the app can be checked from a reachable Kubernetes node:

```bash
curl -f http://<kubernetes-node-ip>:30444/
```

All successful app checks should return JSON similar to:

```json
{"name":"Hello","description":"World","url":"127.0.0.1:4444"}
```

## Ansible Deployments

### Docker Host

`docker-playbook.yml` deploys the container on the Docker machine:

- Pulls the image.
- Removes the previous container.
- Runs the container on port `4444`.
- Fails if `http://127.0.0.1:4444/` does not return HTTP `200`.

Manual run:

```bash
ansible-playbook -i "docker," --private-key="$SSH_KEY" --user="$SSH_USER" -e image=ttl.sh/albertolg101:2h docker-playbook.yml
```

### Target Host

`target-playbook.yml` deploys the app as a systemd service:

- Installs `nodejs` and `npm` with `apt`.
- Copies package files and source into `/opt/myapp`.
- Runs `npm ci --omit=dev`.
- Installs `myapp.service`.
- Enables and restarts the service.
- Fails if `http://127.0.0.1:4444/` does not return HTTP `200`.

Manual run:

```bash
ansible-playbook -i "target," --private-key="$TARGET_SSH_KEY" --user="$TARGET_SSH_USER" target-playbook.yml
```

This target playbook assumes a Debian or Ubuntu host because it uses `apt`.

## Kubernetes

Kubernetes manifests live in `k8s/`:

- `k8s/pod.yaml`: a single Pod named `myapp`.
- `k8s/service.yaml`: a NodePort Service exposing the app on node port `30444`.

Apply manually:

```bash
kubectl delete pod myapp --ignore-not-found=true
kubectl apply -f k8s/pod.yaml
kubectl apply -f k8s/service.yaml
kubectl wait --for=condition=Ready pod/myapp --timeout=120s
```

Access through the node:

```bash
curl http://<node-ip>:30444/
```

The Kubernetes Pod uses readiness and liveness probes against `/` on port `4444`.

## Notes

- The image tag `ttl.sh/albertolg101:2h` is temporary and expires after roughly two hours.
- `PROMPTS.md` records the prompts and implementation decisions used while building this repository.
