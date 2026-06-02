#!/usr/bin/env bash
# setup.sh
# One-time setup: connects two remotes, mirrors customer branch,
# creates your working branch, and installs pre-configured scripts
# into the repo. No .mirror-config file — values are baked in.
#
# SSH-only: all remote URLs must use git@ or ssh:// syntax.
#
# Usage:
#   ./setup.sh
set -euo pipefail

# ── Defaults (override by setting env vars before running) ────────────────
YOUR_REMOTE="${YOUR_REMOTE:-origin}"
CUSTOMER_REMOTE="${CUSTOMER_REMOTE:-customer}"
CUSTOMER_BRANCH="${CUSTOMER_BRANCH:-main}"
MIRROR_BRANCH="${MIRROR_BRANCH:-mirror}"
SCRIPTS_DIR="${SCRIPTS_DIR:-scripts}"

# ── SSH URL validation ─────────────────────────────────────────────────────
validate_ssh_url() {
  local url="$1" label="$2"
  if [[ "$url" =~ ^git@[^:]+:.+$ ]] || [[ "$url" =~ ^ssh://[^@]+@[^/]+ ]]; then
    return 0
  fi
  echo ""
  echo "ERROR: $label URL must use SSH, not HTTPS or file paths."
  echo ""
  echo "  Given : $url"
  echo ""
  echo "  Examples:"
  echo "    git@github.com:org/repo.git"
  echo "    git@gitlab.com:group/repo.git"
  echo "    git@bitbucket.org:workspace/repo.git"
  echo "    git@ssh.dev.azure.com:v3/org/project/repo"
  echo ""
  echo "  Tip: convert https://github.com/org/repo.git → git@github.com:org/repo.git"
  echo ""
  exit 1
}

# ── Validate existing remotes are SSH ─────────────────────────────────────
validate_existing_remotes() {
  local remote url
  while IFS= read -r remote; do
    url=$(git remote get-url "$remote" 2>/dev/null || true)
    if [[ -z "$url" ]]; then continue; fi
    if ! { [[ "$url" =~ ^git@[^:]+:.+$ ]] || [[ "$url" =~ ^ssh://[^@]+@[^/]+ ]]; }; then
      echo ""
      echo "WARNING: existing remote '$remote' uses a non-SSH URL: $url"
      read -rp "Update '$remote' to an SSH URL now? [y/N] " yn
      if [[ "${yn,,}" == "y" ]]; then
        read -rp "New SSH URL for '$remote': " new_url
        validate_ssh_url "$new_url" "$remote"
        git remote set-url "$remote" "$new_url"
        echo "    Updated '$remote' → $new_url"
      else
        echo "    Skipping. Pushes to '$remote' will fail in key-only workflows."
      fi
      echo ""
    fi
  done < <(git remote)
}

echo ""
echo "==> Mirror setup (SSH-only)"
echo ""

validate_existing_remotes

read -rp "Customer repo SSH URL (e.g. git@github.com:org/repo.git): " CUSTOMER_URL
if [[ -z "$CUSTOMER_URL" ]]; then
  echo "ERROR: Customer repo URL is required."
  exit 1
fi
validate_ssh_url "$CUSTOMER_URL" "Customer repo"

echo ""
echo "    your remote    : $YOUR_REMOTE"
echo "    customer remote: $CUSTOMER_REMOTE → $CUSTOMER_URL"
echo "    customer branch: $CUSTOMER_BRANCH"
echo "    mirror branch  : $MIRROR_BRANCH"
echo ""

# ── Add customer remote ───────────────────────────────────────────────────
if ! git remote get-url "$CUSTOMER_REMOTE" &>/dev/null; then
  echo "[1/5] Adding remote '$CUSTOMER_REMOTE'..."
  git remote add "$CUSTOMER_REMOTE" "$CUSTOMER_URL"
else
  current_url=$(git remote get-url "$CUSTOMER_REMOTE")
  if [[ "$current_url" != "$CUSTOMER_URL" ]]; then
    echo "[1/5] Updating remote '$CUSTOMER_REMOTE' URL..."
    git remote set-url "$CUSTOMER_REMOTE" "$CUSTOMER_URL"
  else
    echo "[1/5] Remote '$CUSTOMER_REMOTE' already correct, skipping."
  fi
fi

# ── Fetch both remotes ────────────────────────────────────────────────────
echo "[2/5] Fetching remotes..."
git fetch "$CUSTOMER_REMOTE"
git fetch "$YOUR_REMOTE"

# ── Mirror customer branch to your remote ─────────────────────────────────
echo "[3/5] Mirroring $CUSTOMER_REMOTE/$CUSTOMER_BRANCH → $YOUR_REMOTE/$CUSTOMER_BRANCH..."
git push "$YOUR_REMOTE" "$CUSTOMER_REMOTE/$CUSTOMER_BRANCH:refs/heads/$CUSTOMER_BRANCH"

# ── Create mirror branch on your remote ───────────────────────────────────
echo "[4/5] Creating $YOUR_REMOTE/$MIRROR_BRANCH..."
if git ls-remote --exit-code "$YOUR_REMOTE" "refs/heads/$MIRROR_BRANCH" &>/dev/null; then
  echo "    Already exists, skipping."
else
  git push "$YOUR_REMOTE" "$CUSTOMER_REMOTE/$CUSTOMER_BRANCH:refs/heads/$MIRROR_BRANCH"
fi

# ── Install pre-configured scripts into repo ──────────────────────────────
echo "[5/5] Installing scripts..."
mkdir -p "$SCRIPTS_DIR"
mkdir -p ".github/workflows"

# Detect where this setup.sh lives so we can find sibling scripts
TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Write pull-from-customer.sh ───────────────────────────────────────────
cat > "$SCRIPTS_DIR/pull-from-customer.sh" << EOF
#!/usr/bin/env bash
# pull-from-customer.sh
# Fetches latest from the customer and updates the mirror branch on origin.
# Run manually or let the GitHub Action do it on a schedule.
set -euo pipefail

YOUR_REMOTE="$YOUR_REMOTE"
CUSTOMER_REMOTE="$CUSTOMER_REMOTE"
CUSTOMER_URL="$CUSTOMER_URL"
CUSTOMER_BRANCH="$CUSTOMER_BRANCH"
MIRROR_BRANCH="$MIRROR_BRANCH"

echo ""
echo "==> Pulling from customer"
echo ""
echo "    \$CUSTOMER_REMOTE/\$CUSTOMER_BRANCH → \$YOUR_REMOTE/\$MIRROR_BRANCH"
echo ""

if ! git remote get-url "\$CUSTOMER_REMOTE" &>/dev/null; then
  echo "Adding remote '\$CUSTOMER_REMOTE'..."
  git remote add "\$CUSTOMER_REMOTE" "\$CUSTOMER_URL"
fi

echo "[1/2] Fetching \$CUSTOMER_REMOTE..."
git fetch "\$CUSTOMER_REMOTE"

echo "[2/2] Updating \$YOUR_REMOTE/\$MIRROR_BRANCH..."
git push "\$YOUR_REMOTE" "\$CUSTOMER_REMOTE/\$CUSTOMER_BRANCH:refs/heads/\$MIRROR_BRANCH"

echo ""
echo "==> Mirror up to date."
echo ""
EOF
chmod +x "$SCRIPTS_DIR/pull-from-customer.sh"

# ── Write export-to-customer.sh ───────────────────────────────────────────
cat > "$SCRIPTS_DIR/export-to-customer.sh" << EOF
#!/usr/bin/env bash
# export-to-customer.sh
# Squashes your work into one clean commit and pushes it to the
# customer repo as a branch ready for a PR.
set -euo pipefail

YOUR_REMOTE="$YOUR_REMOTE"
CUSTOMER_REMOTE="$CUSTOMER_REMOTE"
CUSTOMER_URL="$CUSTOMER_URL"
CUSTOMER_BRANCH="$CUSTOMER_BRANCH"
WORK_BRANCH="main"

EXPORT_BRANCH="export/delivery-\$(date +%Y%m%d-%H%M%S)"

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
read -rp "Target branch on customer repo (e.g. feature/delivery-\$(date +%Y-%m-%d)): " TARGET_BRANCH
read -rp "Commit message (what the customer will see): " COMMIT_MESSAGE

if [[ -z "\$TARGET_BRANCH" || -z "\$COMMIT_MESSAGE" ]]; then
  echo "ERROR: Branch name and commit message are required."
  exit 1
fi

echo ""
echo "==> Exporting to customer"
echo "    \$YOUR_REMOTE/\$WORK_BRANCH → \$CUSTOMER_REMOTE/\$TARGET_BRANCH"
echo "    commit: \$COMMIT_MESSAGE"
echo ""

if ! git remote get-url "\$CUSTOMER_REMOTE" &>/dev/null; then
  git remote add "\$CUSTOMER_REMOTE" "\$CUSTOMER_URL"
fi

echo "[1/5] Fetching remotes..."
git fetch "\$CUSTOMER_REMOTE"
git fetch "\$YOUR_REMOTE"

echo "[2/5] Creating clean export branch from customer head..."
git checkout -B "\$EXPORT_BRANCH" "\$CUSTOMER_REMOTE/\$CUSTOMER_BRANCH"

echo "[3/5] Applying your changes..."
git merge --squash "\$YOUR_REMOTE/\$WORK_BRANCH"

echo "[4/5] Stripping internal files..."
for path in "\${EXCLUDE_PATHS[@]}"; do
  git reset HEAD "\$path" 2>/dev/null || true
  git checkout -- "\$path" 2>/dev/null || true
  echo "    excluded: \$path"
done

if git diff --cached --quiet; then
  echo "ERROR: Nothing to commit after stripping internal files."
  git checkout --detach HEAD
  git branch -D "\$EXPORT_BRANCH"
  exit 1
fi

git commit -m "\$COMMIT_MESSAGE"

echo ""
echo "==> Customer will see:"
git log --oneline "\$CUSTOMER_REMOTE/\$CUSTOMER_BRANCH..HEAD"
echo ""
git diff --stat "\$CUSTOMER_REMOTE/\$CUSTOMER_BRANCH..HEAD"
echo ""

echo "[5/5] Pushing to customer and cleaning up..."
git push "\$CUSTOMER_REMOTE" "\$EXPORT_BRANCH:\$TARGET_BRANCH"
git checkout --detach HEAD
git branch -D "\$EXPORT_BRANCH"

echo ""
echo "==> Done. Open a PR on the customer repo from branch: \$TARGET_BRANCH"
echo ""
EOF
chmod +x "$SCRIPTS_DIR/export-to-customer.sh"

# ── Write GitHub Actions workflow ─────────────────────────────────────────
cat > ".github/workflows/sync-mirror.yml" << EOF
name: Sync Mirror

on:
  schedule:
    - cron: '0 * * * *'   # every hour — adjust as needed
  workflow_dispatch:

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "\${{ secrets.SSH_PRIVATE_KEY }}" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
          ssh-keyscan github.com >> ~/.ssh/known_hosts
          # Uncomment for other hosts:
          # ssh-keyscan gitlab.com >> ~/.ssh/known_hosts
          # ssh-keyscan bitbucket.org >> ~/.ssh/known_hosts

      - name: Configure git
        run: |
          git config --global user.email "mirror-bot@users.noreply.github.com"
          git config --global user.name "Mirror Bot"
          git remote set-url origin git@github.com:\${{ github.repository }}.git

      - name: Run sync
        run: bash scripts/pull-from-customer.sh
EOF

echo "    scripts/$SCRIPTS_DIR/pull-from-customer.sh"
echo "    scripts/$SCRIPTS_DIR/export-to-customer.sh"
echo "    .github/workflows/sync-mirror.yml"

# ── Check out mirror branch locally ───────────────────────────────────────
if git show-ref --verify --quiet "refs/heads/$MIRROR_BRANCH"; then
  git checkout "$MIRROR_BRANCH"
else
  git checkout -b "$MIRROR_BRANCH" "$YOUR_REMOTE/$MIRROR_BRANCH"
fi

echo ""
echo "==> Done. You are now on branch '$MIRROR_BRANCH'."
echo ""
echo "Commit and push the scripts to your remote:"
echo "  git add scripts/ .github/"
echo "  git commit -m 'Add mirror toolkit scripts'"
echo "  git push $YOUR_REMOTE $MIRROR_BRANCH"
echo ""
echo "Then add SSH_PRIVATE_KEY to repo secrets:"
echo "  github.com/$(git remote get-url "$YOUR_REMOTE" | sed 's/.*:\(.*\)\.git/\1/')/settings/secrets/actions"
echo ""
echo "Next:"
echo "  Pull customer changes : ./scripts/pull-from-customer.sh"
echo "  Export your work      : ./scripts/export-to-customer.sh"
echo ""