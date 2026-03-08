# 📋 Changelog

All notable changes to this project are documented here. Entries are auto-generated from [Conventional Commits](https://www.conventionalcommits.org/) on every merge to `master`.

> �� This file is **automatically maintained** by the [`changelog.yml`](.github/workflows/changelog.yml) workflow using [git-cliff](https://git-cliff.org/). Do not edit it manually — your changes will be overwritten on the next master merge.

---

## 🏷️ [0.1.0] — 2026-03-08

### ✨ Features

- Bootstrap Kubernetes manifest set for local Docker Desktop cluster
- Add host-based NGINX Ingress routing (`balo-cricket.local` → frontend, `api.balo-cricket.local` → API)
- Add `scripts/setup.sh` — one-command interactive local cluster bootstrap and deploy

### 👷 CI/CD

- Add `changelog.yml` — auto-generates this changelog from conventional commits on every master merge
- Add `commitlint.yml` — enforces Conventional Commits spec on every PR

### 📚 Documentation

- Full `README.md` with architecture diagram, GHCR pull secret guide, published chart usage, one-command setup, and troubleshooting table
