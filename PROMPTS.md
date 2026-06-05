# Prompts

This file records the implementation prompts used to shape the deployment setup.

## Initial Docker and CI Setup

Prompt:

> add a docker file fo this repository

Result:

- Identified the repository as a small Express app listening on port `4444`.
- Deferred the Dockerfile work when the next prompt changed the immediate priority.

Prompt:

> first of all add a myapp service and a jenkinfile

Result:

- Added `package.json` with `start` and `test` scripts and the `express` dependency.
- Added an initial `Dockerfile`.
- Added `.dockerignore`.
- Added `docker-compose.yml` with a `myapp` service exposing port `4444`.
- Added an initial `Jenkinsfile`.
- Verified `npm install` and `npm test`.

## Node Version

Prompt:

> we want to use node 24

Result:

- Updated the Docker base image to `node:24-alpine`.
- Added `"engines": { "node": ">=24" }` to `package.json`.

## Docker Health Check

Prompt:

> add a healthcheck

Result:

- Added a Docker `HEALTHCHECK` that polls `http://localhost:4444/`.

## Test Stage

Prompt:

> note that we want to run tests before building the container

Result:

- Read the latest `Jenkinsfile` to understand the current pipeline state.

Prompt:

> read the jenkinsfile, this is the latest version, add a testing statege

Result:

- Added an initial Jenkins `Test` stage before the `Build` stage.
- The first version ran tests inside a `node:24-alpine` container mounted over the Jenkins workspace.

Prompt:

> is that the best way to run tests?

Result:

- Identified problems with the mounted-container test approach:
  root-owned workspace files, testing a different environment than the shipped image, and duplicated dependency installs.
- Chose a multi-stage Dockerfile approach.
- Converted `Dockerfile` into `base`, `test`, and `prod` stages.
- Updated Jenkins:
  `Test` builds `--target test`; `Build` builds `--target prod`.
- Verified the Docker test target, prod target, local HTTP response, and Docker health status when Docker was available.

Prompt:

> when on build stage does tests run twice?

Result:

- Confirmed tests run only in the Jenkins `Test` stage.
- Explained that the `prod` stage depends on `base`, not on `test`, so Docker skips the test stage during the production build.

## Kubernetes Stretch Work

Prompt:

> now we want to solve this part of the task: Kubernetes manifests (Deployment + Service) - this is the STRETCH portion of the capstone.

Result:

- Added Kubernetes manifests under `k8s/`.
- Started with a Deployment using image `ttl.sh/albertolg101:2h`.
- Added a NodePort Service exposing port `80` to target port `4444` with `nodePort: 30444`.
- Added liveness and readiness probes on `/`.
- Validated the manifests with `kubeconform` because no local Kubernetes cluster was configured.

Prompt:

> we want to ssh into kubernetes machine using kubernetes-ssh-key and deploy myapp from there

Result:

- Added a Jenkins Kubernetes deploy stage using the `kubernetes-ssh-key` credential.
- Added `K8S_HOST = "kubernetes"`.
- The stage SSHed into the Kubernetes host and applied the manifests with `kubectl`.
- Added rollout restart/status handling for the initial Deployment-based version.

Prompt:

> can we have only one container?

Result:

- Updated the Kubernetes Deployment to `replicas: 1`.
- Noted that the pod template already defined only one container.

Prompt:

> why the name of the pod is myapp-67fd744dd7-twrkr and not just myapp?

Result:

- Explained that Deployments create ReplicaSets and Pods with generated suffixes.
- Explained why stable exact pod names are not available through a Deployment.

Prompt:

> I want the pod to be called myapp, I'm not adding any replicas

Result:

- Replaced the Deployment manifest with a bare Pod manifest named `myapp`.
- Renamed the Kubernetes manifest to `k8s/pod.yaml`.
- Removed the Deployment manifest.
- Updated Jenkins Kubernetes deployment to delete and recreate `pod/myapp`, then apply `k8s/service.yaml`.
- Added a `kubectl wait --for=condition=Ready pod/myapp --timeout=120s` readiness wait.
- Validated the Pod and Service manifests with `kubeconform`.

## Deployment Service

Prompt:

> lets add a myapp.service and add a deploy to target using target-ssh-key

Result:

- Added `myapp.service` for running the Node.js app with systemd.
- Added `target-playbook.yml` for deploying the app to the target machine.
- Added a Jenkins `Deploy: Target` stage using the `target-ssh-key` credential.

## Target Dependencies

Prompt:

> assume npm is not in installed yet in target machine

Result:

- Updated `target-playbook.yml` to install `nodejs` and `npm` with `apt` before deploying the app.

## Health Checks

Prompt:

> add a last step to do healthcheck

Result:

- Added a final health check to `target-playbook.yml`.

Prompt:

> if healthcheck fails in target or in docker will the pipeline fail?
> ok, lets do it

Result:

- Added a final health check to `docker-playbook.yml` so Docker deployments fail if the app does not return HTTP `200`.

## Docker Playbook Rename

Prompt:

> rename playbook to docker-playbook

Result:

- Renamed `playbook.yml` to `docker-playbook.yml`.
- Updated the Jenkins Docker deploy stage to use `docker-playbook.yml`.
