#!/usr/bin/env bash
# export-to-customer.sh
# Squashes your work into one clean commit and pushes it to the
# customer repo as a branch ready for a PR.
set -euo pipefail

YOUR_REMOTE="origin"
CUSTOMER_REMOTE="customer"
CUSTOMER_URL="CUSTOMER_URL_PLACEHOLDER"
CUSTOMER_BRANCH="main"
MIRROR_BRANCH="mirror"

EXPORT_BRANCH="export/delivery-$(date +%Y%m%d-%H%M%S)"

# Paths to strip before delivery — customer never sees these
EXCLUDE_PATHS=(
  "scripts/"
  ".github/workflows/sync-mirror.yml"
  ".cursor/"
  ".agents/"
  ".notes/"
  ".cursorrules"
  ".cursorignore"
)

echo ""
read -rp "Target branch on customer repo (e.g. feature/delivery-$(date +%Y-%m-%d)): " TARGET_BRANCH
read -rp "Commit message (what the customer will see): " COMMIT_MESSAGE

if [[ -z "$TARGET_BRANCH" || -z "$COMMIT_MESSAGE" ]]; then
  echo "ERROR: Branch name and commit message are required."
  exit 1
fi

echo ""
echo "==> Exporting to customer"
echo "    $YOUR_REMOTE/$MIRROR_BRANCH → $CUSTOMER_REMOTE/$TARGET_BRANCH"
echo "    commit: $COMMIT_MESSAGE"
echo ""

if ! git remote get-url "$CUSTOMER_REMOTE" &>/dev/null; then
  git remote add "$CUSTOMER_REMOTE" "$CUSTOMER_URL"
fi

echo "[1/5] Fetching remotes..."
git fetch "$CUSTOMER_REMOTE"
git fetch "$YOUR_REMOTE"

echo "[2/5] Creating clean export branch from customer head..."
git checkout -B "$EXPORT_BRANCH" "$CUSTOMER_REMOTE/$CUSTOMER_BRANCH"

echo "[3/5] Applying your changes..."
git merge --squash "$YOUR_REMOTE/$MIRROR_BRANCH"

echo "[4/5] Stripping internal files..."
for path in "${EXCLUDE_PATHS[@]}"; do
  git reset HEAD "$path" 2>/dev/null || true
  git checkout -- "$path" 2>/dev/null || true
  echo "    excluded: $path"
done

if git diff --cached --quiet; then
  echo "ERROR: Nothing to commit after stripping internal files."
  git checkout --detach HEAD
  git branch -D "$EXPORT_BRANCH"
  exit 1
fi

git commit -m "$COMMIT_MESSAGE"

echo ""
echo "==> Customer will see:"
git log --oneline "$CUSTOMER_REMOTE/$CUSTOMER_BRANCH..HEAD"
echo ""
git diff --stat "$CUSTOMER_REMOTE/$CUSTOMER_BRANCH..HEAD"
echo ""

echo "[5/5] Pushing to customer and cleaning up..."
git push "$CUSTOMER_REMOTE" "$EXPORT_BRANCH:$TARGET_BRANCH"
git checkout --detach HEAD
git branch -D "$EXPORT_BRANCH"

echo ""
echo "==> Done. Open a PR on the customer repo from branch: $TARGET_BRANCH"
echo ""