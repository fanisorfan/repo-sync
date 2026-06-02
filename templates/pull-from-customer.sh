#!/usr/bin/env bash
# pull-from-customer.sh
# Fetches latest from the customer and updates the mirror branch on origin.
# Values are baked in by setup.sh — do not edit manually.
set -euo pipefail

YOUR_REMOTE="origin"
CUSTOMER_REMOTE="customer"
CUSTOMER_URL="CUSTOMER_URL_PLACEHOLDER"
CUSTOMER_BRANCH="main"
MIRROR_BRANCH="mirror"

echo ""
echo "==> Pulling from customer"
echo ""
echo "    $CUSTOMER_REMOTE/$CUSTOMER_BRANCH → $YOUR_REMOTE/$MIRROR_BRANCH"
echo ""

if ! git remote get-url "$CUSTOMER_REMOTE" &>/dev/null; then
  echo "Adding remote '$CUSTOMER_REMOTE'..."
  git remote add "$CUSTOMER_REMOTE" "$CUSTOMER_URL"
fi

echo "[1/2] Fetching $CUSTOMER_REMOTE..."
git fetch "$CUSTOMER_REMOTE"

echo "[2/2] Updating $YOUR_REMOTE/$MIRROR_BRANCH..."
git push "$YOUR_REMOTE" "$CUSTOMER_REMOTE/$CUSTOMER_BRANCH:refs/heads/$MIRROR_BRANCH"

echo ""
echo "==> Mirror up to date."
echo ""