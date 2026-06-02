# repo-sync 
Customer Repo Toolkit

A developer toolkit for working on any customer's private GitHub repo while keeping your internal work completely private. Works for any number of customers. Each gets their own isolated working repo.

The customer only ever sees clean, squashed deliveries never your commit history, branch names, or internal tooling.

---

## The concept

For each customer you work with, you maintain:

- A **private internal Git repo** (your working space, fully private)
- Two git remotes: `origin` → your internal repo, `customer` → their repo

You work freely on `main`. A GitHub Action monitors the customer's repo every hour and pulls their changes to a `mirror` branch. When you're ready to deliver, one script squashes your work into a single clean commit and pushes it to them.

---

## Toolkit structure

Keep `setup.sh` somewhere permanent. It works for every customer.

```
repo-sync/
└── setup.sh                          ← run once per customer
```

Each customer project ends up looking like this:

```
<your-internal-repo>/
├── scripts/
│   ├── pull-from-customer.sh         ← pull their changes in manually
│   └── export-to-customer.sh         ← deliver your work to them
├── .github/workflows/
│   └── sync-mirror.yml               ← auto-monitors their repo every hour
└── ... your code ...
```

---

## Starting a new customer project

1. Create a new private repository for your work (e.g. on GitHub, GitLab) and clone it locally.
2. Inside your local repository, run the setup script:

```bash
/path/to/repo-sync/setup.sh
```

It asks for:

```
Customer repo SSH URL (e.g. git@github.com:org/repo.git):
```

Then automatically:
- Adds the customer's repo as a remote (`customer`)
- Fetches and mirrors their `main` branch to your `mirror` branch
- Installs the sync scripts and GitHub Action workflow
- Asks you to commit and push the new tooling to your remote

> **Note**: This toolkit is SSH-only. Make sure your remotes use `git@...` URLs.

---

## Authentication for the GitHub Action

To allow the GitHub Action to pull from the customer's repository and automatically update the mirror, add an SSH private key as a repository secret:

1. Generate an SSH key pair (or use an existing one that has read access to the customer's repo).
2. Give the public key to the customer so they can add it as a Deploy Key (or add it to a machine user account).
3. Add the private key as a secret in your internal repo:
   → **Settings → Secrets and variables → Actions → New repository secret**

| Name | Value |
|---|---|
| `SSH_PRIVATE_KEY` | your private SSH key contents |

---

## Everyday workflow

### Working on code

Work on `main` as you normally would. Commit freely the customer never sees individual commits.

```bash
git add .
git commit -m "implement feature"
git push origin main
```

### Pulling customer changes

The monitor runs every hour. If they pushed something, the Action will automatically pull it to your `mirror` branch.

To pull immediately without waiting:

```bash
./scripts/pull-from-customer.sh
```

### Delivering to the customer

```bash
./scripts/export-to-customer.sh
```

Prompts:

```
Target branch on customer repo (e.g. feature/delivery-2026-05-14): feature/auth-implementation
Commit message (what the customer will see): Implement authentication flow
```

Then it creates a clean branch from the customer's head, squashes all your work into one commit, strips internal tooling, and pushes to the customer's repo. Go to their repository and open a PR from that branch.

---

## Rules

- **Never push `main` directly to the customer** always use `export-to-customer.sh`
- **Never commit to `mirror`** it's a read-only mirror of their repo
- **Always work on `main`** or feature branches off it
- The following are automatically stripped on every export and never reach the customer:

```
scripts/
.github/workflows/sync-mirror.yml
.cursor/
.agents/
.notes/
.cursorrules
.cursorignore
```

To add more paths, edit the `EXCLUDE_PATHS` array at the top of `scripts/export-to-customer.sh`.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Monitor workflow fails with SSH error | Ensure `SSH_PRIVATE_KEY` is set correctly and the public key has read access to the customer repo |
| Export says "nothing to commit" | You have no code changes yet only internal tooling was added |
| Customer can't see your PR | Make sure you pushed to their repo, not your internal one |

