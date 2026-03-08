# 🏏 balo-cricket-k8s-manifest

> One command to go from zero to a fully running Balo Cricket platform on your local Kubernetes cluster.

This repository holds all the Kubernetes / Helm manifests needed to run the two services that make up the **Balo Cricket** platform side-by-side in a local Docker Desktop cluster:

| Service | Image | What it does |
|---------|-------|--------------|
| 🎨 **Frontend** | `ghcr.io/samoclay/balo-cricket-react-frontend-ui` | React UI served on port 80 |
| ⚙️ **API** | `ghcr.io/samoclay/balo-cricket-api` | Backend REST API served on port 8080 |

Both images are stored in the **GitHub Container Registry (GHCR)**. The chart defaults to `latest` for each image; you can pin any published version via `--set`.

---

## 🗺️ How it all fits together

```
Your browser
     │
     │  http://balo-cricket.local          http://api.balo-cricket.local
     ▼                                              ▼
┌─────────────────────────────────────────────────────────┐
│              NGINX Ingress Controller                   │
│                 (Docker Desktop LB)                     │
└──────────────────┬──────────────────────────────────────┘
                   │ routes by hostname
        ┌──────────┴──────────┐
        ▼                     ▼
┌───────────────┐    ┌─────────────────────┐
│   Frontend    │    │        API          │
│   Deployment  │◄───│   Deployment        │
│  (React, :80) │    │  (Node/Go/etc :8080)│
└───────────────┘    └─────────────────────┘
        both live in the  balo-cricket  namespace
```

The **React frontend** calls the API using the `REACT_APP_API_URL` environment variable, which is set to `http://api.balo-cricket.local` by default — the same hostname the ingress exposes.

---

## 📁 Repository structure

```
.
├── scripts/
│   └── setup.sh                 ⭐ one-command local setup & deploy
│
├── helm/
│   └── balo-cricket/            🎯 Helm chart (deploy this!)
│       ├── Chart.yaml           chart metadata & version
│       ├── values.yaml          all tuneable defaults
│       └── templates/           k8s resource templates
│
├── dev/                         📄 raw YAML manifests (reference only)
│   ├── namespace.yaml
│   ├── secrets.yaml
│   ├── ingress.yaml
│   ├── frontend/
│   └── api/
│
├── CHANGELOG.md                 📋 auto-generated from conventional commits
├── cliff.toml                   ⚙️  git-cliff config (drives CHANGELOG)
├── .commitlintrc.yml            📏 conventional commit rules for PRs
│
└── .github/workflows/
    ├── helm-test.yml            🧪 PR: lint + schema + image check
    ├── chart-release.yml        🚀 master: publish chart + enrich release notes
    ├── changelog.yml            📋 master: auto-update CHANGELOG.md
    └── commitlint.yml           📏 PR: validate commit message format
```

---

## ⚡ Quick start — one command

```bash
git clone https://github.com/samoclay/balo-cricket-k8s-manifest.git
cd balo-cricket-k8s-manifest
./scripts/setup.sh
```

That's it. The script walks you through every step interactively. ☕ grab a coffee while it sets up.

---

## 🛠️ Prerequisites

Before running the setup script you need these three tools installed:

| Tool | Why | Install |
|------|-----|---------|
| 🐳 **Docker Desktop** | Runs your local Kubernetes cluster | [download](https://www.docker.com/products/docker-desktop/) |
| ☸️ **kubectl** | Talk to the cluster | [install guide](https://kubernetes.io/docs/tasks/tools/) |
| ⛵ **Helm 3** | Deploy the chart | [install guide](https://helm.sh/docs/intro/install/) |

### Enable Kubernetes in Docker Desktop

1. Open Docker Desktop → **Settings** → **Kubernetes**
2. Check **Enable Kubernetes** → **Apply & Restart**
3. Wait for the green Kubernetes status dot 🟢

---

## 🔑 Secrets you'll need

The setup script prompts you for these. If you prefer to pass them as environment variables (e.g. for scripted setups), set them before running:

```bash
export GHCR_USER="your-github-username"
export GHCR_TOKEN="ghp_xxxxxxxxxxxx"   # GitHub PAT — read:packages scope
export JWT_SECRET="super-secret-jwt"
export API_KEY="my-api-key"
./scripts/setup.sh
```

### 🐙 Creating a GitHub PAT for GHCR

Both container images live in the **GitHub Container Registry** — your local Kubernetes cluster must be able to pull them. The cluster does this via an `imagePullSecret` (just like AWS ECS uses ECR credentials or EKS uses an ECR token).

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. Click **Generate new token**
3. Give it a name like `balo-cricket-k8s-pull`
4. Tick only **`read:packages`** — that's all the cluster needs
5. Copy the token — you'll only see it once

The setup script takes this token and creates a Kubernetes secret called `ghcr-pull-secret` in the `balo-cricket` namespace. The Helm chart then tells every pod to use that secret when pulling images — exactly the same pattern as `imagePullSecrets` with ECR credentials on AWS.

If you ever need to recreate it manually:

```bash
kubectl create secret docker-registry ghcr-pull-secret \
  --namespace=balo-cricket \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-github-pat> \
  --docker-email=<your-email>
```

---

## 📦 Helm chart — using the published repository

Every time a feature branch is merged into **master**, the CI pipeline automatically packages the chart and publishes it to the Helm repository hosted on **GitHub Pages**. The chart version is driven by the `version` field in `helm/balo-cricket/Chart.yaml`.

### Add the Helm repo

```bash
helm repo add balo-cricket https://samoclay.github.io/balo-cricket-k8s-manifest
helm repo update
```

### 🔍 Browse all available chart versions

```bash
helm search repo balo-cricket --versions
```

Example output:

```
NAME                        CHART VERSION   APP VERSION   DESCRIPTION
balo-cricket/balo-cricket   0.2.0           latest        Balo Cricket platform — React frontend UI and ...
balo-cricket/balo-cricket   0.1.0           latest        Balo Cricket platform — React frontend UI and ...
```

### 🗺️ See which container images a chart version uses

```bash
# Show the full default values for a specific chart version
helm show values balo-cricket/balo-cricket --version 0.1.0
```

Look for the `frontend.image` and `api.image` blocks — they tell you exactly which image repository and tag that chart version was built against:

```yaml
frontend:
  image:
    repository: ghcr.io/samoclay/balo-cricket-react-frontend-ui
    tag: latest

api:
  image:
    repository: ghcr.io/samoclay/balo-cricket-api
    tag: latest
```

To pin specific image versions when installing:

```bash
helm install balo-cricket balo-cricket/balo-cricket \
  --namespace balo-cricket \
  --set frontend.image.tag=1.2.0 \
  --set api.image.tag=2.0.1 \
  --set api.secrets.jwtSecret=<your-jwt-secret> \
  --set api.secrets.apiKey=<your-api-key>
```

---

## 🚀 Getting started — step by step

### Option 1 — 🤖 Automated (recommended)

The setup script handles everything below in one go:

```bash
./scripts/setup.sh
```

**Optional flags:**

```bash
# Deploy a specific published chart version instead of the local chart
./scripts/setup.sh --chart-version 0.2.0

# Preview all steps without making any changes
./scripts/setup.sh --dry-run
```

### Option 2 — 🔧 Manual steps

If you prefer to understand each step or want more control:

#### 1️⃣ Add local DNS entries

Add these two lines to your hosts file so the ingress hostnames resolve to `localhost`:

**macOS / Linux** — `/etc/hosts`  
**Windows** — `C:\Windows\System32\drivers\etc\hosts`

```
127.0.0.1  balo-cricket.local
127.0.0.1  api.balo-cricket.local
```

#### 2️⃣ Install the NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml

# Wait for it to be ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

> 💡 Check the [ingress-nginx releases page](https://github.com/kubernetes/ingress-nginx/releases) to confirm `v1.11.3` is still the latest stable version.

#### 3️⃣ Create the namespace

```bash
kubectl create namespace balo-cricket
```

#### 4️⃣ Create the GHCR pull secret

```bash
kubectl create secret docker-registry ghcr-pull-secret \
  --namespace=balo-cricket \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-github-pat> \
  --docker-email=<your-email>
```

#### 5️⃣ Deploy with Helm

```bash
# From the published Helm repo:
helm install balo-cricket balo-cricket/balo-cricket \
  --namespace balo-cricket \
  --set api.secrets.jwtSecret=<your-jwt-secret> \
  --set api.secrets.apiKey=<your-api-key>

# Or from the local chart in this repo:
helm install balo-cricket ./helm/balo-cricket \
  --namespace balo-cricket \
  --set api.secrets.jwtSecret=<your-jwt-secret> \
  --set api.secrets.apiKey=<your-api-key>
```

#### 6️⃣ Verify

```bash
kubectl get all -n balo-cricket
kubectl get ingress -n balo-cricket
```

#### 7️⃣ Open in your browser

| 🌐 Frontend | http://balo-cricket.local |
|-------------|---------------------------|
| 🔌 API      | http://api.balo-cricket.local |

---

## ♻️ Updating / upgrading

To upgrade to a newer chart version or change any value, use `helm upgrade`:

```bash
helm upgrade balo-cricket balo-cricket/balo-cricket \
  --namespace balo-cricket \
  --version 0.2.0 \
  --set api.secrets.jwtSecret=<your-jwt-secret> \
  --set api.secrets.apiKey=<your-api-key>
```

Or just re-run the setup script with `--chart-version`:

```bash
./scripts/setup.sh --chart-version 0.2.0
```

## 🗑️ Tearing down

```bash
helm uninstall balo-cricket -n balo-cricket
kubectl delete namespace balo-cricket
```

---

## 🔄 CI / CD — how the chart is published

Every push to `master` (i.e. every merged PR) triggers this pipeline:

```
Feature branch  ──► PR ──► master merge
                     │              │
                     ▼              ▼
              On every PR:    On every master push:
              ─────────────   ──────────────────────────────────
              commitlint.yml  changelog.yml
              → validates     → git-cliff reads conventional
                all commit      commits → rewrites CHANGELOG.md
                messages        → commits back to master

              helm-test.yml   chart-release.yml
              → helm lint     → if Chart.yaml version bumped:
              → kubeconform     ① package chart .tgz
                (k8s 1.28 +     ② create GitHub Release
                 k8s 1.30)           balo-cricket-<ver>
              → docker          ③ enrich release notes:
                manifest            • bundled image versions
                inspect             • upstream changelogs from
                (both images)         balo-cricket-react-frontend-ui
                                      balo-cricket-api
                                ④ push index.yaml → gh-pages
                                   (live Helm repo)
```

### ⬆️ Bumping the chart version

When you want to publish a new chart release, bump `version` in `helm/balo-cricket/Chart.yaml` **before** merging:

```yaml
# helm/balo-cricket/Chart.yaml
version: 0.2.0    # ← increment this (semantic versioning)
```

Commit it as:

```bash
git commit -m "helm: bump chart version to 0.2.0"
```

`chart-release.yml` is idempotent — it only creates a GitHub Release when it finds a version that doesn't already have one, so merges that don't touch the chart version are safe no-ops.

### 🏷️ What a GitHub Release looks like

Each chart release at `https://github.com/samoclay/balo-cricket-k8s-manifest/releases` automatically includes:

- 📦 **Bundled image versions** — the exact frontend and API image tags this chart was built with
- 🎨 **Frontend changelog** — release notes fetched live from `samoclay/balo-cricket-react-frontend-ui`
- ⚙️ **API changelog** — release notes fetched live from `samoclay/balo-cricket-api`
- 🔄 **Chart changes** — conventional commits since the previous chart tag

This means every chart release is self-contained and tells you exactly what's inside — no digging through commit history needed.

> 💡 **Why GitHub Releases instead of a RELEASE.md file?**  
> GitHub Releases are versioned, searchable, and appear directly on the repo homepage.  
> A `RELEASE.md` file would go stale between versions and only ever show one release at a time.  
> Use `CHANGELOG.md` for the full commit history and GitHub Releases for user-facing per-version notes.

---

## 📝 Contributing — Conventional Commits

This project uses **[Conventional Commits](https://www.conventionalcommits.org/)** so that the changelog and release notes are generated automatically. Every commit must follow this format:

```
<type>(<optional scope>): <short description in lowercase>

[optional body]

[optional footer — use BREAKING CHANGE: for breaking changes]
```

### Commit types

| Type | Emoji | When to use |
|------|-------|-------------|
| `feat` | ✨ | A new feature or user-facing capability |
| `fix` | 🐛 | A bug fix |
| `docs` | 📚 | Documentation only changes |
| `helm` | ⛵ | Helm chart changes — values, templates, Chart.yaml version bumps |
| `ci` | 👷 | CI/CD workflow changes |
| `chore` | 🔧 | Maintenance, dependency bumps, housekeeping |
| `refactor` | ♻️ | Code restructure with no behavior change |
| `perf` | ⚡ | Performance improvements |
| `test` | 🧪 | Adding or fixing tests |
| `style` | 🎨 | Formatting / whitespace only |
| `revert` | ⏪ | Reverts a previous commit |

### Examples

```bash
feat: add staging environment values overlay
fix: correct readiness probe path for API container
helm: bump chart version to 0.2.0
docs: add AWS deployment section to README
ci: add trivy image vulnerability scanning
chore: update NGINX Ingress Controller to v1.12.0
feat!: rename balo-cricket namespace to cricket    # ⚠️ breaking change
```

Breaking changes use `!` after the type and will be flagged prominently in the changelog and release notes.

The `commitlint.yml` workflow validates every commit in a PR automatically — it will block the merge if any message doesn't follow the spec.

---

## 🔧 Troubleshooting

| Symptom | Fix |
|---------|-----|
| `ImagePullBackOff` on pods | The `ghcr-pull-secret` is missing or has wrong credentials. Re-run `./scripts/setup.sh` or recreate the secret manually (see step 4 above). |
| `curl: (6) Could not resolve host: balo-cricket.local` | The `/etc/hosts` entries are missing. Add them (the setup script does this with `sudo`). |
| Ingress returns 404 | The NGINX Ingress Controller may still be starting. Run `kubectl get pods -n ingress-nginx` and wait for `Running`. |
| `helm: command not found` | Install Helm 3: https://helm.sh/docs/intro/install/ |
| `Error: INSTALLATION FAILED: cannot re-use a name that is still in use` | A previous release exists. Use `helm upgrade` instead of `helm install`, or run the setup script (it uses `helm upgrade --install`). |

---

## 🗺️ Roadmap

- [ ] 🏗️ AWS deployment manifests (`aws/` environment overlay)
- [ ] 🔐 Sealed Secrets or External Secrets Operator integration
- [ ] 📊 Prometheus / Grafana monitoring stack
- [ ] 🔄 Dependabot for automated image tag bumps
