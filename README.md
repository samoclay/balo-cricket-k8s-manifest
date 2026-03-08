# balo-cricket-k8s-manifest

Kubernetes manifests for deploying the Balo Cricket platform — comprising the React frontend UI and the backend API — to a local Kubernetes cluster (Docker Desktop) and, in future, to AWS.

## Repository structure

```
dev/                          # Local / development environment
├── namespace.yaml            # balo-cricket namespace
├── secrets.yaml              # API authentication secrets (template — edit before applying)
├── ingress.yaml              # Nginx Ingress routing rules
├── frontend/
│   ├── deployment.yaml       # React UI Deployment
│   └── service.yaml          # React UI ClusterIP Service
└── api/
    ├── deployment.yaml       # Backend API Deployment
    └── service.yaml          # Backend API ClusterIP Service
```

## Container images

| Component | Image |
|-----------|-------|
| Frontend  | `ghcr.io/samoclay/balo-cricket-react-frontend-ui:latest` |
| API       | `ghcr.io/samoclay/balo-cricket-api:latest` |

Both images are hosted in the GitHub Container Registry (GHCR). Update the `image:` field in each deployment if you want to pin to a specific tag.

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

### 1. Add local DNS entries

Add the following lines to `/etc/hosts` (macOS/Linux) or `C:\Windows\System32\drivers\etc\hosts` (Windows):

```
127.0.0.1  balo-cricket.local
127.0.0.1  api.balo-cricket.local
```

### 2. Create the image pull secret

The images are stored in GHCR and require a GitHub Personal Access Token (PAT) with `read:packages` scope.

```bash
kubectl create secret docker-registry ghcr-pull-secret \
  --namespace=balo-cricket \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-github-pat> \
  --docker-email=<your-email>
```

### 3. Update the API secrets

Edit `dev/secrets.yaml` and replace the placeholder values for `JWT_SECRET` and `API_KEY` with real values **before** applying.

> **Note:** Do not commit real secret values. Consider using `kubectl create secret` directly or a secrets manager for sensitive data.

### 4. Apply manifests

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
