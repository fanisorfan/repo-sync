# repo-sync 
Customer Repo Toolkit

A developer toolkit for working on any customer's private GitHub repo while keeping your internal work completely private. Works for any number of customers. Each gets their own isolated working repo.

The customer only ever sees clean, squashed deliveries never your commit history, branch names, or internal tooling.

---

## The concept

For each customer you work with, you maintain:

- A **private internal GitHub repo** (your working space, fully private)
- A **local working folder** cloned from the customer, rewired to your internal repo
- Two git remotes: `origin` → your internal repo, `customer` → their repo

You work freely on `internal-main`. A GitHub Action monitors the customer's repo every 6 hours and opens a PR if they push something. When you're ready to deliver, one script squashes your work into a single clean commit and pushes it to them.

---

## Toolkit structure

Keep this folder somewhere permanent. One toolkit, works for every customer.

```
repo-sync/
├── setup.sh                          ← run once per customer
└── templates/                        ← don't touch these
    ├── pull-from-customer.sh
    ├── export-to-customer.sh
    └── .github/workflows/
        └── monitor-customer.yml
```

Each customer project ends up looking like this:

```
<customer-repo-name>/
├── scripts/
│   ├── pull-from-customer.sh         ← pull their changes in manually
│   └── export-to-customer.sh        ← deliver your work to them
├── .github/workflows/
│   └── monitor-customer.yml          ← auto-monitors their repo every 6h
└── ... their code ...
```

---

## Requirements

Install the GitHub CLI once setup uses it to create repos automatically:

```bash
brew install gh
gh auth login
```

---

## Starting a new customer project

Go to whatever folder you want the project to live in, then run setup:

```bash
/path/to/repo-sync/setup.sh
```

It asks for one thing:

```
Customer repo URL (SSH or HTTPS): https://github.com/acme-org/backend.git
```

Then automatically:
- Creates a private GitHub repo under your account
- Clones the customer's codebase as the starting point
- Creates `internal-main` as your working branch
- Installs the scripts and monitor workflow
- Pushes everything to your internal repo

Run it again any time to start over from scratch it wipes and rebuilds cleanly.

---

## GitHub token (once per account, works for all customers)

Create one classic token that covers all your customer repos:

1. GitHub → profile picture → **Settings**
2. **Developer settings → Personal access tokens → Tokens (classic) → Generate new token (classic)**
3. Note: `repo-sync`, Expiration: 1 year, Scope: tick **`repo`**
4. Generate and copy it

For each customer project, add it as a secret in your internal repo:
→ **Settings → Secrets and variables → Actions → New repository secret**

| Name | Value |
|---|---|
| `REPO_TOKEN` | your classic token |

> Ask each customer to add you as a collaborator on their repo so your token can read it:
> their repo → **Settings → Collaborators → Add people** → your GitHub username

---

## Everyday workflow

### Working on code

Work on `internal-main` as you normally would. Commit freely the customer never sees individual commits.

```bash
git add .
git commit -m "implement feature"
git push origin internal-main
```

### Pulling customer changes

The monitor runs every 6 hours. If they pushed something, a PR appears on your internal repo. Review and merge it if you need their changes.

To pull immediately without waiting:

```bash
./scripts/pull-from-customer.sh
```

Shows incoming commits, asks for a merge message, merges and pushes.

### Delivering to the customer

```bash
./scripts/export-to-customer.sh
```

Prompts:

```
Target branch name (e.g. feature/delivery-2026-05-14): feature/auth-implementation
Commit message (what the customer will see): Implement authentication flow
```

Then squashes all your internal commits into one clean commit, strips internal tooling, and pushes to the customer's repo. Go to their GitHub and open a PR from that branch.

---

## Working with multiple customers

Each customer is a completely separate folder and repo they're fully isolated from each other. The toolkit is shared and reused for every customer.

The scripts inside each customer folder are pre-configured for that specific customer by `setup.sh`, so you never need to think about which customer you're targeting just `cd` into the right folder and run the script.

---

## Rules

- **Never push `internal-main` directly to the customer** always use `export-to-customer.sh`
- **Never commit to `customer-main`** it's a read-only mirror of their repo, updated automatically
- **Always work on `internal-main`** or feature branches off it
- The following are automatically stripped on every export and never reach the customer:

```
scripts/
.github/workflows/monitor-customer.yml
.cursor/
.agents/
.notes/
.cursorrules
.cursorignore
.junie/
.tanstack/
```

To add more paths, edit the `EXCLUDE_PATHS` array at the top of `scripts/export-to-customer.sh`.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Setup fails mid-way | Run `setup.sh` again it starts clean |
| Monitor workflow fails with "no token" | Add `REPO_TOKEN` secret to your internal repo |
| Export says "nothing to commit" | You have no code changes yet only internal tooling was added |
| Pull opens vim for merge message | Type `:wq` and press Enter to accept |
| Customer can't see your PR | Make sure you pushed to their repo, not your internal one |
