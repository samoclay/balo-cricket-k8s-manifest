# 🏏 balo-cricket-k8s-manifest

> Deployment manifests and one-command local setup for the Balo Cricket platform.

This repository holds the **Kubernetes deployment manifests** and the **local cluster setup script** for the two services that make up Balo Cricket, deployed using a published Helm chart.

| Service | Image | What it does |
|---------|-------|--------------|
| 🎨 **Frontend** | `ghcr.io/samoclay/balo-cricket-react-frontend-ui` | React UI served on port 80 |
| ⚙️ **API** | `ghcr.io/samoclay/balo-cricket-api` | Backend REST API served on port 8080 |

> 📦 **Helm chart**: The chart is maintained in a separate repository — [`samoclay/balo-cricket-helm-chart`](https://github.com/samoclay/balo-cricket-helm-chart). This repo consumes published chart releases from that repo.

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

---

## 📁 Repository structure

```
.
├── scripts/
│   └── setup.sh          ⭐ one-command local setup & deploy
│
├── dev/                   📄 raw YAML manifests (reference / direct kubectl apply)
│   ├── namespace.yaml
│   ├── secrets.yaml
│   ├── ingress.yaml
│   ├── frontend/
│   └── api/
│
├── CHANGELOG.md           📋 auto-generated from conventional commits
├── cliff.toml             ⚙️  git-cliff config (drives CHANGELOG)
├── .commitlintrc.yml      📏 conventional commit rules for PRs
│
└── .github/workflows/
    ├── changelog.yml      📋 master: auto-update CHANGELOG.md
    └── commitlint.yml     📏 PR: validate commit message format
```

---

## ⚡ Quick start — one command

```bash
git clone https://github.com/samoclay/balo-cricket-k8s-manifest.git
cd balo-cricket-k8s-manifest
./scripts/setup.sh
```

The script walks you through every step interactively. ☕ grab a coffee while it sets up.

---

## 🛠️ Prerequisites

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

The setup script prompts you for these. If you prefer to pass them as environment variables:

```bash
export GHCR_USER="your-github-username"
export GHCR_TOKEN="ghp_xxxxxxxxxxxx"   # GitHub PAT — read:packages scope
export JWT_SECRET="super-secret-jwt"
export API_KEY="my-api-key"
./scripts/setup.sh
```

### 🐙 Creating a GitHub PAT for GHCR

Both container images live in the **GitHub Container Registry** — your local Kubernetes cluster must pull them using an `imagePullSecret`.

1. Go to **GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. Click **Generate new token**
3. Give it a name like `balo-cricket-k8s-pull`
4. Tick only **`read:packages`**
5. Copy the token — you'll only see it once

---

## 📦 Helm chart — finding and using published versions

The Helm chart is published from [`samoclay/balo-cricket-helm-chart`](https://github.com/samoclay/balo-cricket-helm-chart) and served via GitHub Pages.

### Add the Helm repo

```bash
helm repo add balo-cricket https://samoclay.github.io/balo-cricket-helm-chart
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

Each published chart release on [`samoclay/balo-cricket-helm-chart`](https://github.com/samoclay/balo-cricket-helm-chart/releases) includes:

- 📦 The exact **frontend and API image versions** bundled in that chart
- 🎨 **Frontend release notes** from [`samoclay/balo-cricket-react-frontend-ui`](https://github.com/samoclay/balo-cricket-react-frontend-ui/releases)
- ⚙️ **API release notes** from [`samoclay/balo-cricket-api`](https://github.com/samoclay/balo-cricket-api/releases)
- 🔄 Chart-level changes since the previous version

### 🗺️ See which container images a chart version uses

```bash
helm show values balo-cricket/balo-cricket --version 0.1.0
```

Look for the `frontend.image` and `api.image` blocks.

---

## 🚀 Getting started — step by step

### Option 1 — 🤖 Automated (recommended)

```bash
./scripts/setup.sh
```

**Optional flags:**

```bash
# Deploy a specific published chart version
./scripts/setup.sh --chart-version 0.2.0

# Preview all steps without making any changes
./scripts/setup.sh --dry-run
```

### Option 2 — 🔧 Manual steps

#### 1️⃣ Add local DNS entries

**macOS / Linux** — `/etc/hosts`
**Windows** — `C:\Windows\System32\drivers\etc\hosts`

```
127.0.0.1  balo-cricket.local
127.0.0.1  api.balo-cricket.local
```

#### 2️⃣ Install the NGINX Ingress Controller

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/cloud/deploy.yaml
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

#### 3️⃣ Create the namespace and GHCR pull secret

```bash
kubectl create namespace balo-cricket

kubectl create secret docker-registry ghcr-pull-secret \
  --namespace=balo-cricket \
  --docker-server=ghcr.io \
  --docker-username=<your-github-username> \
  --docker-password=<your-github-pat> \
  --docker-email=<your-email>
```

#### 4️⃣ Deploy with Helm

```bash
helm repo add balo-cricket https://samoclay.github.io/balo-cricket-helm-chart
helm repo update

helm install balo-cricket balo-cricket/balo-cricket \
  --namespace balo-cricket \
  --set api.secrets.jwtSecret=<your-jwt-secret> \
  --set api.secrets.apiKey=<your-api-key>
```

#### 5️⃣ Verify

```bash
kubectl get all -n balo-cricket
kubectl get ingress -n balo-cricket
```

#### 6️⃣ Open in your browser

| 🌐 Frontend | http://balo-cricket.local |
|-------------|---------------------------|
| 🔌 API      | http://api.balo-cricket.local |

---

## ♻️ Upgrading

```bash
helm repo update
helm upgrade balo-cricket balo-cricket/balo-cricket \
  --namespace balo-cricket \
  --version 0.2.0 \
  --set api.secrets.jwtSecret=<your-jwt-secret> \
  --set api.secrets.apiKey=<your-api-key>
```

Or re-run the setup script:

```bash
./scripts/setup.sh --chart-version 0.2.0
```

## 🗑️ Tearing down

```bash
helm uninstall balo-cricket -n balo-cricket
kubectl delete namespace balo-cricket
```

---

## 📋 CHANGELOG.md vs GitHub Releases — what lives where

| | CHANGELOG.md | GitHub Releases (chart repo) |
|-|---|---|
| **What it tracks** | Every conventional commit merged to `master` in *this* repo | Each versioned chart release |
| **Who updates it** | `changelog.yml` workflow — auto-committed after every master merge | `chart-release.yml` in `balo-cricket-helm-chart` |
| **Audience** | Contributors to this repo | Operators / end-users deploying the chart |
| **Content** | Commit-level changes (features, fixes, CI changes) | Bundled image versions + upstream release notes |

---

## 📝 Contributing — Conventional Commits

Every commit must follow **[Conventional Commits](https://www.conventionalcommits.org/)**:

```
<type>(<optional scope>): <short description in lowercase>
```

| Type | Emoji | When to use |
|------|-------|-------------|
| `feat` | ✨ | A new feature or capability |
| `fix` | 🐛 | A bug fix |
| `docs` | 📚 | Documentation only |
| `ci` | 👷 | CI/CD workflow changes |
| `chore` | 🔧 | Maintenance, dependency bumps |
| `refactor` | ♻️ | Code restructure, no behavior change |
| `perf` | ⚡ | Performance improvements |
| `test` | 🧪 | Adding or fixing tests |
| `style` | 🎨 | Formatting / whitespace only |
| `revert` | ⏪ | Reverts a previous commit |

**Examples:**

```bash
feat: add staging environment overlay
fix: correct readiness probe path for API
docs: update manual deployment steps in README
ci: add CHANGELOG auto-update workflow
chore: update NGINX Ingress Controller to v1.12.0
```

The `commitlint.yml` workflow validates every commit in a PR automatically. On every master merge, `changelog.yml` regenerates `CHANGELOG.md` using [git-cliff](https://git-cliff.org/).

---

## 🔧 Troubleshooting

| Symptom | Fix |
|---------|-----|
| `ImagePullBackOff` on pods | The `ghcr-pull-secret` is missing or has wrong credentials. Re-run `./scripts/setup.sh` or recreate the secret manually. |
| `curl: (6) Could not resolve host: balo-cricket.local` | The `/etc/hosts` entries are missing. Add them (the setup script does this with `sudo`). |
| Ingress returns 404 | The NGINX Ingress Controller may still be starting. Run `kubectl get pods -n ingress-nginx` and wait for `Running`. |
| `helm: command not found` | Install Helm 3: https://helm.sh/docs/intro/install/ |
| `Error: INSTALLATION FAILED: cannot re-use a name that is still in use` | A previous release exists. Use `helm upgrade` instead of `helm install`, or re-run the setup script. |
| Chart version not found | Run `helm repo update` to refresh the index, then `helm search repo balo-cricket --versions` to list what's available. |

---

## 🗺️ Roadmap

- [ ] 🏗️ AWS deployment overlay (`aws/` environment)
- [ ] 🔐 Sealed Secrets or External Secrets Operator integration
- [ ] 📊 Prometheus / Grafana monitoring stack
- [ ] 🔄 Dependabot for automated image tag bumps
