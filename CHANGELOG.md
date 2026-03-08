# 📋 Changelog

All notable changes to this project are documented here. Entries are auto-generated from [Conventional Commits](https://www.conventionalcommits.org/) on every merge to `master`.

> 🤖 This file is **automatically maintained** by the [`changelog.yml`](.github/workflows/changelog.yml) workflow using [git-cliff](https://git-cliff.org/). Do not edit it manually — your changes will be overwritten on the next master merge.

---

## 🏷️ [0.1.0] — 2026-03-08

### ✨ Features

- Bootstrap Kubernetes manifest set for local Docker Desktop cluster
- Add Helm chart (`helm/balo-cricket/`) with parameterised values for frontend and API
- Add host-based NGINX Ingress routing (`balo-cricket.local` → frontend, `api.balo-cricket.local` → API)
- Add `scripts/setup.sh` — one-command interactive local cluster bootstrap and deploy

### ⛵ Helm Chart

- Initial chart version `0.1.0` packaging both `balo-cricket-react-frontend-ui` and `balo-cricket-api`
- Image pull secret (`ghcr-pull-secret`) wired through chart for GHCR authentication
- API secrets (`JWT_SECRET`, `API_KEY`) injected via Kubernetes Secret and `envFrom`
- Ingress toggle via `ingress.enabled` value

### 👷 CI/CD

- Add `helm-test.yml` — PR validation: `helm lint`, `kubeconform` schema check against k8s 1.28 + 1.30, `docker manifest inspect` for both images
- Add `chart-release.yml` — publishes versioned Helm chart to GitHub Pages Helm repository on every master merge
- Add `changelog.yml` — auto-generates this changelog from conventional commits on every master merge
- Add `commitlint.yml` — enforces Conventional Commits spec on every PR

### 📚 Documentation

- Full `README.md` with architecture diagram, GHCR pull secret guide, Helm repo instructions, chart version browsing, one-command setup, and troubleshooting table
