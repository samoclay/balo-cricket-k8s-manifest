# balo-cricket-k8s-manifest

Kubernetes manifests for deploying the Balo Cricket platform — comprising the React frontend UI and the backend API — to a local Kubernetes cluster (Docker Desktop) and, in future, to AWS.

## Repository structure

```
helm/
└── balo-cricket/             # Helm chart (preferred deployment method)
    ├── Chart.yaml
    ├── values.yaml           # Default values (dev / Docker Desktop)
    └── templates/
        ├── namespace.yaml
        ├── secret.yaml
        ├── frontend-deployment.yaml
        ├── frontend-service.yaml
        ├── api-deployment.yaml
        ├── api-service.yaml
        └── ingress.yaml

dev/                          # Raw manifests (quick local reference)
├── namespace.yaml
├── secrets.yaml
├── ingress.yaml
├── frontend/
│   ├── deployment.yaml
│   └── service.yaml
└── api/
    ├── deployment.yaml
    └── service.yaml

.github/workflows/
└── helm-test.yml             # CI: lint · schema validation · image check
```

## Container images

| Component | Image |
|-----------|-------|
| Frontend  | `ghcr.io/samoclay/balo-cricket-react-frontend-ui:latest` |
| API       | `ghcr.io/samoclay/balo-cricket-api:latest` |

Both images are hosted in the GitHub Container Registry (GHCR). The image tags default to `latest`; override `frontend.image.tag` / `api.image.tag` in `values.yaml` (or via `--set`) to pin to a specific version.

## CI — Helm chart tests

The `.github/workflows/helm-test.yml` workflow runs automatically on every push or PR that touches `helm/` or the workflow file itself. It contains three jobs:

| Job | Tool | What it checks |
|-----|------|----------------|
| **Helm Lint** | `helm lint --strict` | Chart structure, template syntax, required fields |
| **Template Render & Schema Validation** | `helm template` + `kubeconform` | All rendered manifests are valid Kubernetes resources (tested against k8s 1.28 and 1.30) |
| **Verify Container Images** | `docker manifest inspect` | Both GHCR images exist and are accessible — only fetches manifest JSON, no layers downloaded |

> **GHCR_TOKEN secret required** — the *Verify Container Images* job needs a repository secret named `GHCR_TOKEN` set to a GitHub Personal Access Token with `read:packages` scope. Add it at **Settings → Secrets and variables → Actions**.

## Prerequisites

* [Docker Desktop](https://www.docker.com/products/docker-desktop/) with Kubernetes enabled
* [kubectl](https://kubernetes.io/docs/tasks/tools/) configured to use the `docker-desktop` context
* [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/deploy/#docker-desktop) installed in the cluster

### Install NGINX Ingress Controller (Docker Desktop)

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
```

> **Note:** Verify `controller-v1.10.1` is the latest stable release before applying. Check the [releases page](https://github.com/kubernetes/ingress-nginx/releases) for the current version.

## Deployment

### Option A — Helm (recommended)

Helm allows you to override any value without editing files and makes future environment promotion straightforward.

#### 1. Add local DNS entries

Add the following lines to `/etc/hosts` (macOS/Linux) or `C:\Windows\System32\drivers\etc\hosts` (Windows):

```
127.0.0.1  balo-cricket.local
127.0.0.1  api.balo-cricket.local
```

#### 2. Create the image pull secret

The images are stored in GHCR and require a GitHub Personal Access Token (PAT) with `read:packages` scope.

```bash
kubectl create namespace balo-cricket

kubectl create secret docker-registry ghcr-pull-secret \
  --namespace=balo-cricket \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-github-pat> \
  --docker-email=<your-email>
```

#### 3. Install the chart

```bash
helm install balo-cricket helm/balo-cricket \
  --namespace balo-cricket \
  --set api.secrets.jwtSecret=<your-jwt-secret> \
  --set api.secrets.apiKey=<your-api-key>
```

To pin specific image versions instead of `latest`:

```bash
helm install balo-cricket helm/balo-cricket \
  --namespace balo-cricket \
  --set frontend.image.tag=1.2.3 \
  --set api.image.tag=2.0.1 \
  --set api.secrets.jwtSecret=<your-jwt-secret> \
  --set api.secrets.apiKey=<your-api-key>
```

#### 4. Verify and access

```bash
kubectl get all -n balo-cricket
kubectl get ingress -n balo-cricket
```

* **Frontend:** http://balo-cricket.local
* **API:** http://api.balo-cricket.local

---

### Option B — Raw manifests (quick local reference)

```bash
# Create namespace first
kubectl apply -f dev/namespace.yaml

# Apply secrets
kubectl apply -f dev/secrets.yaml

# Deploy the API
kubectl apply -f dev/api/

# Deploy the frontend
kubectl apply -f dev/frontend/

# Apply ingress rules
kubectl apply -f dev/ingress.yaml
```

Or apply everything at once (namespace must exist first):

```bash
kubectl apply -f dev/namespace.yaml
kubectl apply -f dev/ --recursive
```

### 5. Verify the deployment

```bash
kubectl get all -n balo-cricket
kubectl get ingress -n balo-cricket
```

### 6. Access the application

* **Frontend:** http://balo-cricket.local
* **API:** http://api.balo-cricket.local

## Future: AWS deployment

A future `aws/` (or `staging/` / `prod/`) directory will be added alongside `dev/` for cloud deployments. The manifest structure is designed to allow environment-specific overrides (e.g. via Kustomize overlays) without duplicating base resources.
