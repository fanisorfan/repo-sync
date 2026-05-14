#!/usr/bin/env bash
# pull-from-customer.sh
# Manually pull the latest changes from the customer repo into your internal branch.
#
# Usage:
#   ./scripts/pull-from-customer.sh

set -euo pipefail

CUSTOMER_REMOTE="customer"
CUSTOMER_URL="CUSTOMER_URL_PLACEHOLDER"
CUSTOMER_BRANCH="${CUSTOMER_BRANCH:-main}"
INTERNAL_BRANCH="${INTERNAL_BRANCH:-internal-main}"

# ── Ensure customer remote exists ─────────────────────────────────────────
if ! git remote get-url "$CUSTOMER_REMOTE" &>/dev/null; then
  git remote add "$CUSTOMER_REMOTE" "$CUSTOMER_URL"
fi

echo ""
echo "==> Pulling from customer"
echo "    $CUSTOMER_REMOTE/$CUSTOMER_BRANCH  →  $INTERNAL_BRANCH"
echo ""

# ── Fetch ─────────────────────────────────────────────────────────────────
echo "[1/3] Fetching..."
git fetch "$CUSTOMER_REMOTE"

# ── Show incoming commits ─────────────────────────────────────────────────
INCOMING=$(git log --oneline HEAD.."$CUSTOMER_REMOTE/$CUSTOMER_BRANCH")
if [ -z "$INCOMING" ]; then
  echo "Already up to date. Nothing to pull."
  exit 0
fi
echo ""
echo "Incoming commits from customer:"
echo "$INCOMING"
echo ""

# ── Ask for merge message ─────────────────────────────────────────────────
read -rp "Merge commit message: " MERGE_MESSAGE
if [ -z "$MERGE_MESSAGE" ]; then
  MERGE_MESSAGE="Merge customer changes into internal-main"
fi

# ── Merge and push ────────────────────────────────────────────────────────
echo ""
echo "[2/3] Merging into $INTERNAL_BRANCH..."
git checkout "$INTERNAL_BRANCH"
git merge "$CUSTOMER_REMOTE/$CUSTOMER_BRANCH" --no-ff -m "$MERGE_MESSAGE"

echo "[3/3] Pushing..."
git push origin "$INTERNAL_BRANCH"

echo ""
echo "==> Done."
echo ""