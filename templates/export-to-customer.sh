#!/usr/bin/env bash
# export-to-customer.sh
# Squashes your internal work into one clean commit and pushes it
# to the customer repo as a branch ready for a PR.
# Internal tooling, IDE config, and agent directories are stripped
# automatically — the customer never sees them.

set -euo pipefail

CUSTOMER_REMOTE="customer"
CUSTOMER_URL="CUSTOMER_URL_PLACEHOLDER"
CUSTOMER_BRANCH="${CUSTOMER_BRANCH:-main}"
INTERNAL_BRANCH="${INTERNAL_BRANCH:-internal-main}"
EXPORT_BRANCH="export/customer-$(date +%Y%m%d-%H%M%S)"

# ── Files and folders to exclude from the export ─────────────────────────
# Internal tooling and IDE/agent config that should never reach the customer
EXCLUDE_PATHS=(
  "scripts"
  ".github/workflows/monitor-customer.yml"
  ".cursor"
  ".agents"
  ".notes"
  ".cursorrules"
  ".cursorignore"
  ".junie"
  ".tanstack"
)

# ── Ask for required inputs ───────────────────────────────────────────────
echo ""
read -rp "Target branch name (e.g. feature/delivery-$(date +%Y-%m-%d)): " TARGET_BRANCH
read -rp "Commit message (what the customer will see): " COMMIT_MESSAGE

if [[ -z "$TARGET_BRANCH" || -z "$COMMIT_MESSAGE" ]]; then
  echo "ERROR: Both branch name and commit message are required."
  exit 1
fi

# ── Make sure we are on internal-main ────────────────────────────────────
git checkout -f "$INTERNAL_BRANCH"

# ── Ensure customer remote exists ─────────────────────────────────────────
if ! git remote get-url "$CUSTOMER_REMOTE" &>/dev/null; then
  git remote add "$CUSTOMER_REMOTE" "$CUSTOMER_URL"
fi

echo ""
echo "==> Exporting to customer"
echo "    $INTERNAL_BRANCH  →  $CUSTOMER_REMOTE/$TARGET_BRANCH"
echo "    commit: $COMMIT_MESSAGE"
echo ""

# ── 1. Fetch customer's latest ────────────────────────────────────────────
echo "[1/5] Fetching customer's latest..."
git fetch "$CUSTOMER_REMOTE"

# ── 2. Create throwaway branch from their head ────────────────────────────
echo "[2/5] Creating clean export branch..."
git checkout -B "$EXPORT_BRANCH" "$CUSTOMER_REMOTE/$CUSTOMER_BRANCH"

# ── 3. Apply changes ──────────────────────────────────────────────────────
echo "[3/5] Applying your changes..."
git diff "$CUSTOMER_REMOTE/$CUSTOMER_BRANCH".."$INTERNAL_BRANCH" | git apply --index 2>/dev/null || \
  git merge --squash "$INTERNAL_BRANCH" --allow-unrelated-histories

# ── 4. Exclude internal files from the commit ────────────────────────────
echo "[4/5] Excluding internal files..."
for path in "${EXCLUDE_PATHS[@]}"; do
  git reset HEAD "$path" 2>/dev/null || true
  git checkout -- "$path" 2>/dev/null || true
  echo "    excluded: $path"
done

git commit -m "$COMMIT_MESSAGE"

# ── Show what the customer will see ───────────────────────────────────────
echo ""
echo "==> Customer will see:"
git log --oneline "$CUSTOMER_REMOTE/$CUSTOMER_BRANCH..HEAD"
echo ""
git diff --stat "$CUSTOMER_REMOTE/$CUSTOMER_BRANCH..HEAD"
echo ""

# ── 5. Push and clean up ──────────────────────────────────────────────────
echo "[5/5] Pushing to customer..."
git push "$CUSTOMER_REMOTE" "$EXPORT_BRANCH:$TARGET_BRANCH"

git checkout -f "$INTERNAL_BRANCH"
git branch -D "$EXPORT_BRANCH"

echo ""
echo "==> Done. Open a PR on the customer's GitHub from branch: $TARGET_BRANCH"
echo ""