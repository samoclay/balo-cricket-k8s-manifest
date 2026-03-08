#!/usr/bin/env python3
"""
enrich-release.py — builds rich GitHub Release notes for a balo-cricket chart release.

Reads:
  helm/balo-cricket/Chart.yaml   → chart version
  helm/balo-cricket/values.yaml  → frontend + API image repo and tag

Fetches from GitHub API:
  Release notes for the frontend image tag from samoclay/balo-cricket-react-frontend-ui
  Release notes for the API image tag from samoclay/balo-cricket-api

Writes the assembled release body to /tmp/release-body.md.

The workflow then calls:
  gh release edit balo-cricket-<version> --notes-file /tmp/release-body.md

Required environment variables:
  GH_TOKEN            GitHub token with contents:read on the image repos
  GITHUB_REPOSITORY   Owner/repo of this chart repo (set automatically by GitHub Actions)
"""

import json
import os
import subprocess
import sys
import textwrap
from urllib.error import HTTPError
from urllib.request import Request, urlopen

try:
    import yaml
except ImportError:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "pyyaml"])
    import yaml  # noqa: E402  (re-import after install)

# ── Read chart metadata ────────────────────────────────────────────────────────
chart  = yaml.safe_load(open("helm/balo-cricket/Chart.yaml"))
values = yaml.safe_load(open("helm/balo-cricket/values.yaml"))

chart_version  = chart["version"]
frontend_image = values["frontend"]["image"]["repository"]
frontend_tag   = values["frontend"]["image"]["tag"]
api_image      = values["api"]["image"]["repository"]
api_tag        = values["api"]["image"]["tag"]

# Derive GitHub repo slugs from the GHCR path
# e.g. ghcr.io/samoclay/balo-cricket-api → samoclay/balo-cricket-api
frontend_gh_repo = "/".join(frontend_image.split("/")[-2:])
api_gh_repo      = "/".join(api_image.split("/")[-2:])

gh_token        = os.environ["GH_TOKEN"]
gh_repo_full    = os.environ["GITHUB_REPOSITORY"]


# ── Helpers ────────────────────────────────────────────────────────────────────
def fetch_release_notes(gh_repo: str, tag: str) -> str | None:
    """Return the body of a GitHub Release for gh_repo@tag, or None if not found."""
    url = f"https://api.github.com/repos/{gh_repo}/releases/tags/{tag}"
    req = Request(
        url,
        headers={
            "Authorization": f"Bearer {gh_token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    try:
        with urlopen(req) as resp:
            data = json.loads(resp.read())
            return data.get("body", "").strip() or None
    except HTTPError as exc:
        print(f"  ℹ️  No GitHub Release for {gh_repo}@{tag} (HTTP {exc.code})")
        return None


def conventional_commits_since_last_tag() -> str:
    """
    Return a markdown list of conventional commits since the previous chart tag.
    Falls back to a placeholder if no conventional commits are found.
    """
    tags_result = subprocess.run(
        ["git", "tag", "--sort=-version:refname"],
        capture_output=True, text=True,
    )
    chart_tags = [
        t for t in tags_result.stdout.splitlines()
        if t.startswith("balo-cricket-")
    ]

    current_tag = f"balo-cricket-{chart_version}"
    try:
        idx      = chart_tags.index(current_tag)
        prev_tag = chart_tags[idx + 1] if idx + 1 < len(chart_tags) else None
    except ValueError:
        # Current tag doesn't exist yet (release not published) — use the newest existing tag
        prev_tag = chart_tags[0] if chart_tags else None

    log_range = f"{prev_tag}..HEAD" if prev_tag else "HEAD"
    log_result = subprocess.run(
        ["git", "log", "--pretty=format:- %s", log_range],
        capture_output=True, text=True,
    )

    cc_types = (
        "feat", "fix", "helm", "ci", "chore",
        "refactor", "perf", "test", "docs", "style", "revert",
    )
    all_lines = log_result.stdout.strip().splitlines() if log_result.stdout.strip() else []
    chart_commits = [
        line for line in all_lines
        if any(line.startswith(f"- {t}") for t in cc_types)
    ][:25]

    if chart_commits:
        return "\n".join(chart_commits)
    return "_No conventional commits recorded since the previous release._"


# ── Fetch upstream release notes ───────────────────────────────────────────────
print(f"Chart {chart_version} | Frontend {frontend_image}:{frontend_tag} | API {api_image}:{api_tag}")

fe_notes  = fetch_release_notes(frontend_gh_repo, frontend_tag)
api_notes = fetch_release_notes(api_gh_repo, api_tag)

fe_notes_md = fe_notes or (
    f"_No GitHub Release found for tag `{frontend_tag}` — "
    f"check [releases](https://github.com/{frontend_gh_repo}/releases)._"
)
api_notes_md = api_notes or (
    f"_No GitHub Release found for tag `{api_tag}` — "
    f"check [releases](https://github.com/{api_gh_repo}/releases)._"
)

chart_changes_md = conventional_commits_since_last_tag()

# ── Assemble the release body ──────────────────────────────────────────────────
body = f"""\
## ⛵ Balo Cricket Helm Chart — `{chart_version}`

Deploy the complete Balo Cricket platform to your local Kubernetes cluster:

```bash
helm repo add balo-cricket https://samoclay.github.io/balo-cricket-k8s-manifest
helm repo update
./scripts/setup.sh --chart-version {chart_version}
```

---

### 📦 Bundled container images

| Service | Image | Version |
|---------|-------|---------|
| 🎨 **Frontend** | `{frontend_image}` | `{frontend_tag}` |
| ⚙️ **API** | `{api_image}` | `{api_tag}` |

---

### 🔄 What changed in this chart release

{chart_changes_md}

---

### 🎨 Frontend — what's new in `{frontend_tag}`

{fe_notes_md}

---

### ⚙️ API — what's new in `{api_tag}`

{api_notes_md}

---

> 📋 Full commit history: [CHANGELOG.md](https://github.com/{gh_repo_full}/blob/master/CHANGELOG.md)
"""

output_path = "/tmp/release-body.md"
with open(output_path, "w") as f:
    f.write(body)

print(f"Release body written to {output_path} ({len(body)} chars)")
