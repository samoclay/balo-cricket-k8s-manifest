#!/usr/bin/env bash
# =============================================================================
# setup.sh — Bootstrap and deploy the Balo Cricket platform to a local
#             Kubernetes cluster (Docker Desktop).
#
# Usage:
#   ./scripts/setup.sh                    # interactive — prompts for secrets
#   ./scripts/setup.sh --chart-version 0.2.0   # pin a specific published version
#   ./scripts/setup.sh --dry-run          # print what would happen, no changes
#
# Environment variables (skip interactive prompts):
#   GHCR_USER       GitHub username for GHCR pull secret
#   GHCR_TOKEN      GitHub PAT with read:packages scope
#   JWT_SECRET      API JWT secret
#   API_KEY         API key
# =============================================================================
set -euo pipefail

# ── Colours & helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "  ${CYAN}ℹ${RESET}  $*"; }
success() { echo -e "  ${GREEN}✅${RESET} $*"; }
warn()    { echo -e "  ${YELLOW}⚠️${RESET}  $*"; }
error()   { echo -e "  ${RED}❌${RESET} $*" >&2; exit 1; }
step()    { echo -e "\n${BOLD}${CYAN}▶ $*${RESET}"; }
dryrun()  { echo -e "  ${YELLOW}[dry-run]${RESET} $*"; }

# ── Defaults ──────────────────────────────────────────────────────────────────
NAMESPACE="balo-cricket"
RELEASE_NAME="balo-cricket"
HELM_CHART_DIR="$(cd "$(dirname "$0")/.." && pwd)/helm/balo-cricket"
INGRESS_VERSION="v1.11.3"
INGRESS_DEPLOY_URL="https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-${INGRESS_VERSION}/deploy/static/provider/cloud/deploy.yaml"
FRONTEND_HOST="balo-cricket.local"
API_HOST="api.balo-cricket.local"
CHART_VERSION=""   # empty = use local chart; set via --chart-version to use published
DRY_RUN=false

# ── Argument parsing ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --chart-version) CHART_VERSION="$2"; shift 2 ;;
    --dry-run)       DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--chart-version <ver>] [--dry-run]"
      echo ""
      echo "  --chart-version <ver>   Deploy a published chart version from the Helm repo"
      echo "                          (e.g. 0.2.0).  Omit to deploy from the local chart."
      echo "  --dry-run               Print what would happen without making any changes."
      echo ""
      echo "Environment variables:"
      echo "  GHCR_USER    GitHub username (skips prompt)"
      echo "  GHCR_TOKEN   GitHub PAT with read:packages scope (skips prompt)"
      echo "  JWT_SECRET   API JWT secret (skips prompt)"
      echo "  API_KEY      API key (skips prompt)"
      exit 0 ;;
    *) error "Unknown argument: $1" ;;
  esac
done

run() {
  # Wrapper that respects --dry-run
  if $DRY_RUN; then
    dryrun "$*"
  else
    "$@"
  fi
}

# ── Banner ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${CYAN}"
echo "  🏏  Balo Cricket — Local Cluster Setup"
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${RESET}"
$DRY_RUN && warn "DRY-RUN mode — no changes will be made"

# ── Step 1: Check prerequisites ───────────────────────────────────────────────
step "Checking prerequisites"

for tool in docker kubectl helm; do
  if command -v "$tool" &>/dev/null; then
    success "$tool found ($(command -v "$tool"))"
  else
    error "$tool is not installed or not on PATH. See README for install links."
  fi
done

# ── Step 2: Verify Docker Desktop Kubernetes is running ───────────────────────
step "Checking Kubernetes cluster"

if $DRY_RUN; then
  dryrun "kubectl cluster-info  # skipped in dry-run"
  info "Skipping live cluster checks in dry-run mode"
elif ! kubectl cluster-info &>/dev/null; then
  error "Cannot reach a Kubernetes cluster. Make sure Docker Desktop Kubernetes is enabled and running."
else
  CONTEXT=$(kubectl config current-context)
  info "Current context: ${BOLD}${CONTEXT}${RESET}"

  if [[ "$CONTEXT" != "docker-desktop" ]]; then
    warn "Context is '${CONTEXT}', not 'docker-desktop'."
    echo -e "  ${YELLOW}This script is intended for Docker Desktop. Continue anyway? [y/N]${RESET} \c"
    read -r confirm
    [[ "${confirm,,}" == "y" ]] || { echo "Aborted."; exit 1; }
  fi
  success "Cluster is reachable"
fi

# ── Step 3: Install NGINX Ingress Controller ──────────────────────────────────
step "Checking NGINX Ingress Controller"

if ! $DRY_RUN && kubectl get deployment ingress-nginx-controller -n ingress-nginx &>/dev/null; then
  success "NGINX Ingress Controller already installed — skipping"
else
  info "Installing NGINX Ingress Controller ${INGRESS_VERSION}..."
  run kubectl apply -f "$INGRESS_DEPLOY_URL"

  if ! $DRY_RUN; then
    info "Waiting for ingress controller to become ready (up to 90s)..."
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=90s
  fi
  success "NGINX Ingress Controller installed"
fi

# ── Step 4: Create namespace ──────────────────────────────────────────────────
step "Setting up namespace: ${NAMESPACE}"

if ! $DRY_RUN && kubectl get namespace "$NAMESPACE" &>/dev/null; then
  success "Namespace '${NAMESPACE}' already exists — skipping"
else
  run kubectl create namespace "$NAMESPACE"
  success "Namespace '${NAMESPACE}' created"
fi

# ── Step 5: GHCR image pull secret ────────────────────────────────────────────
step "Configuring GHCR image pull secret"

if ! $DRY_RUN && kubectl get secret ghcr-pull-secret -n "$NAMESPACE" &>/dev/null; then
  success "ghcr-pull-secret already exists in namespace '${NAMESPACE}'"
  echo -e "  ${YELLOW}Recreate it? [y/N]${RESET} \c"
  read -r recreate
  if [[ "${recreate,,}" == "y" ]]; then
    kubectl delete secret ghcr-pull-secret -n "$NAMESPACE"
  else
    info "Keeping existing secret"
    recreate="n"
  fi
else
  recreate="y"
fi

if [[ "${recreate:-y}" == "y" ]]; then
  # Collect credentials
  if [[ -z "${GHCR_USER:-}" ]]; then
    echo -e "  ${CYAN}GitHub username (for GHCR pull):${RESET} \c"
    read -r GHCR_USER
  else
    info "Using GHCR_USER from environment: ${GHCR_USER}"
  fi

  if [[ -z "${GHCR_TOKEN:-}" ]]; then
    echo -e "  ${CYAN}GitHub PAT (read:packages scope) — input hidden:${RESET} \c"
    read -rs GHCR_TOKEN
    echo ""
  else
    info "Using GHCR_TOKEN from environment"
  fi

  run kubectl create secret docker-registry ghcr-pull-secret \
    --namespace="$NAMESPACE" \
    --docker-server=ghcr.io \
    --docker-username="$GHCR_USER" \
    --docker-password="$GHCR_TOKEN" \
    --docker-email="${GHCR_USER}@users.noreply.github.com"
  success "ghcr-pull-secret created"
fi

# ── Step 6: Collect API secrets ───────────────────────────────────────────────
step "Collecting API secrets"

if [[ -z "${JWT_SECRET:-}" ]]; then
  echo -e "  ${CYAN}JWT secret for the API (input hidden):${RESET} \c"
  read -rs JWT_SECRET
  echo ""
else
  info "Using JWT_SECRET from environment"
fi

if [[ -z "${API_KEY:-}" ]]; then
  echo -e "  ${CYAN}API key (input hidden):${RESET} \c"
  read -rs API_KEY
  echo ""
else
  info "Using API_KEY from environment"
fi

# ── Step 7: Add /etc/hosts entries ────────────────────────────────────────────
step "Configuring local DNS (/etc/hosts)"

HOSTS_FILE="/etc/hosts"
UPDATED_HOSTS=false

for host in "$FRONTEND_HOST" "$API_HOST"; do
  if grep -qF "$host" "$HOSTS_FILE" 2>/dev/null; then
    success "${host} already in ${HOSTS_FILE}"
  else
    info "Adding ${host} → 127.0.0.1 (requires sudo)"
    if $DRY_RUN; then
      dryrun "echo '127.0.0.1  ${host}' >> /etc/hosts"
    else
      echo "127.0.0.1  ${host}" | sudo tee -a "$HOSTS_FILE" > /dev/null
    fi
    UPDATED_HOSTS=true
  fi
done

$UPDATED_HOSTS && success "/etc/hosts updated"

# ── Step 8: Helm repo (if using a published version) ─────────────────────────
if [[ -n "$CHART_VERSION" ]]; then
  step "Adding Balo Cricket Helm repo"

  HELM_REPO_URL="https://samoclay.github.io/balo-cricket-k8s-manifest"

  if helm repo list 2>/dev/null | grep -q "balo-cricket"; then
    success "Helm repo 'balo-cricket' already added"
    run helm repo update balo-cricket
  else
    run helm repo add balo-cricket "$HELM_REPO_URL"
    run helm repo update
  fi

  CHART_REF="balo-cricket/balo-cricket"
  VERSION_FLAG="--version ${CHART_VERSION}"
  success "Will deploy published chart version ${CHART_VERSION}"
else
  step "Using local chart"
  CHART_REF="$HELM_CHART_DIR"
  VERSION_FLAG=""
  info "Chart path: ${CHART_REF}"
fi

# ── Step 9: Deploy / upgrade with Helm ───────────────────────────────────────
step "Deploying Helm release '${RELEASE_NAME}'"

HELM_CMD=(
  helm upgrade --install "$RELEASE_NAME" $CHART_REF
  ${VERSION_FLAG:+$VERSION_FLAG}
  --namespace "$NAMESPACE"
  --create-namespace
  --set "api.secrets.jwtSecret=${JWT_SECRET}"
  --set "api.secrets.apiKey=${API_KEY}"
  --wait
  --timeout 120s
)

run "${HELM_CMD[@]}"
success "Helm release '${RELEASE_NAME}' deployed"

# ── Step 10: Status summary ───────────────────────────────────────────────────
step "Deployment summary"

if ! $DRY_RUN; then
  echo ""
  kubectl get pods -n "$NAMESPACE"
  echo ""
  kubectl get ingress -n "$NAMESPACE"
fi

echo ""
echo -e "${BOLD}${GREEN}🏏 Balo Cricket is ready!${RESET}"
echo ""
echo -e "  🌐 Frontend:  ${BOLD}http://${FRONTEND_HOST}${RESET}"
echo -e "  🔌 API:       ${BOLD}http://${API_HOST}${RESET}"
echo ""
echo -e "  Useful commands:"
echo -e "    kubectl get all -n ${NAMESPACE}"
echo -e "    kubectl logs -n ${NAMESPACE} deploy/balo-cricket-frontend"
echo -e "    kubectl logs -n ${NAMESPACE} deploy/balo-cricket-api"
echo -e "    helm status ${RELEASE_NAME} -n ${NAMESPACE}"
echo ""
