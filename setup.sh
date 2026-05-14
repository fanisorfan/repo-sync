#!/usr/bin/env bash
# setup.sh
# Run this from whatever folder you want the customer repo to live in.
# It creates a new folder there, sets everything up, and pushes to GitHub.

set -euo pipefail

SETUP_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="$(pwd)"

echo ""
echo "============================================"
echo "  Customer Repo Sync — Setup"
echo "============================================"
echo ""

# ── Check gh CLI ──────────────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
  echo "ERROR: GitHub CLI (gh) is required."
  echo "  Install: brew install gh"
  echo "  Auth   : gh auth login"
  exit 1
fi

# ── Ask for customer URL only ─────────────────────────────────────────────
read -rp "Customer repo URL (SSH or HTTPS): " CUSTOMER_URL

REPO_NAME=$(basename "$CUSTOMER_URL" .git)
REPO_DIR="$WORK_DIR/$REPO_NAME"
GITHUB_USER=$(gh api user --jq '.login')
INTERNAL_URL="git@github.com:$GITHUB_USER/$REPO_NAME.git"

echo ""
echo "  Will create : $REPO_DIR"
echo "  GitHub repo : https://github.com/$GITHUB_USER/$REPO_NAME"
echo ""

# ── Wipe local folder if it exists ────────────────────────────────────────
if [ -d "$REPO_DIR" ]; then
  echo "==> Removing existing '$REPO_NAME' folder..."
  rm -rf "$REPO_DIR"
fi

# ── 1. Create internal GitHub repo (delete and recreate if exists) ─────────
echo "[1/6] Setting up internal GitHub repo..."
if gh repo view "$GITHUB_USER/$REPO_NAME" &>/dev/null 2>&1; then
  echo "    Already exists — deleting and recreating clean..."
  gh repo delete "$GITHUB_USER/$REPO_NAME" --yes
fi
gh repo create "$REPO_NAME" --private
echo "    Created."

# ── 2. Clone customer repo into current directory ─────────────────────────
echo "[2/6] Cloning customer repo into $(pwd)/$REPO_NAME..."
git clone "$CUSTOMER_URL" "$REPO_DIR"
cd "$REPO_DIR"

# ── 3. Rewire remotes ─────────────────────────────────────────────────────
echo "[3/6] Configuring remotes..."
git remote set-url origin "$INTERNAL_URL"
git remote add customer "$CUSTOMER_URL"

# ── 4. Create internal-main and push ──────────────────────────────────────
echo "[4/6] Creating internal-main branch..."
git checkout -b internal-main
git push -u origin internal-main
gh repo edit "$GITHUB_USER/$REPO_NAME" --default-branch internal-main 2>/dev/null || true

# ── 5. Install scripts and workflow ───────────────────────────────────────
echo "[5/6] Installing scripts and workflow..."
mkdir -p scripts .github/workflows

sed "s|CUSTOMER_URL_PLACEHOLDER|$CUSTOMER_URL|g" \
  "$SETUP_DIR/templates/pull-from-customer.sh" > scripts/pull-from-customer.sh

sed "s|CUSTOMER_URL_PLACEHOLDER|$CUSTOMER_URL|g" \
  "$SETUP_DIR/templates/export-to-customer.sh" > scripts/export-to-customer.sh

sed "s|CUSTOMER_URL_PLACEHOLDER|$CUSTOMER_URL|g" \
  "$SETUP_DIR/templates/.github/workflows/monitor-customer.yml" > .github/workflows/monitor-customer.yml

chmod +x scripts/pull-from-customer.sh scripts/export-to-customer.sh

# ── 6. Commit and push ────────────────────────────────────────────────────
echo "[6/6] Committing and pushing..."
git add scripts/ .github/
git commit -m "chore: add customer sync scripts and monitor workflow"
git push origin internal-main

echo ""
echo "============================================"
echo "  Ready"
echo "============================================"
echo ""
echo "  Created at  : $REPO_DIR"
echo "  Internal    : https://github.com/$GITHUB_USER/$REPO_NAME"
echo "  Customer    : $CUSTOMER_URL"
echo ""
echo "  Add these two secrets:"
echo "  → https://github.com/$GITHUB_USER/$REPO_NAME/settings/secrets/actions"
echo ""
echo "    INTERNAL_REPO_TOKEN   fine-grained token: contents + pull-requests write on this repo"
echo "    CUSTOMER_REPO_TOKEN   classic token with repo scope"
echo ""
echo "  Then cd into your repo and start working:"
echo "  cd $REPO_DIR"
echo ""