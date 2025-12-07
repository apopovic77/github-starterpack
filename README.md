# DevOps Starter Pack

Production-ready scripts, docs, and GitHub Actions workflows that turn any **Node.js or PHP** project into a CI/CD-enabled app with SSH deployments. Designed so humans and AI agents can install and operate the release process with predictable steps.

**Supported Project Types:**
- ✅ Node.js (React, Vue, Vite, Next.js, etc.)
- ✅ PHP (plain PHP, Laravel, WordPress, Symfony, etc.)
- ✅ Playwright Tests (E2E testing with Playwright)

---

## 📦 What You Get

- `.devops/scripts/` – helper CLI scripts for syncing branches, building locally, releasing, deploying, and rolling back.
- `.github/workflows/` – CI for the development branch and a full build/deploy workflow for production pushes.
- `.devops/*.md` – bootstrap documentation (release flow, setup, agent instructions) populated with your project paths.
- `scripts/setup-devops.sh` – installer that copies templates into a target repo and replaces placeholders with your values.

All files are plain Bash/Markdown/Node workflows so they can be adapted for other stacks by editing defaults during installation.

---

## ✅ Requirements

**For Node.js projects:**
- Git, Node.js, npm (or compatible package manager)

**For PHP projects:**
- Git, PHP (8.0+), optionally Composer

**For all projects:**
- GitHub CLI (`gh`) authenticated if you want to push directly after installation
- SSH access to the deployment server (public key must be added to `authorized_keys`)
- GitHub repository secrets for deployment:
  - `DEPLOY_HOST`
  - `DEPLOY_USER`
  - `DEPLOY_SSH_KEY` (private key corresponding to the authorized public key)
  - `DEPLOY_PORT` *(optional, default 22)*

## 🔍 Auto-Detection

The installer automatically detects your project type:

**Playwright Test Detection:**
- Looks for `playwright.config.ts` or `playwright.config.js`
- Configures test-specific workflows (scheduled tests, post-deployment tests)
- Sets build command to "npm test"
- No traditional deployment (tests run in GitHub Actions)

**PHP Detection:**
- Looks for `composer.json` or `*.php` files
- Sets build command to "no build needed"
- Uses PHP-optimized GitHub Actions workflows
- Direct rsync deployment (no npm build step)

**Node.js Detection:**
- Looks for `package.json`
- Configures npm/yarn build pipeline
- Uses Node.js GitHub Actions workflows
- Builds and deploys `dist/` folder

You can override auto-detection with `--build-command` and `--install-deps` flags.

---

## 🚀 Quick Start (Human or AI Agent)

1. Clone/download this starter pack (or run via GitHub Codespaces/CLI).
2. Execute the installer, targeting your project directory:
   ```bash
   /var/code/github-starterpack/scripts/setup-devops.sh \
     --target /path/to/project \
     --project-name "My App" \
     --site-url https://app.example.com \
     --repo-root /path/to/project \
     --deploy-path /var/www/my-app
   ```
   - Omit flags to answer interactive prompts.
   - Add `--non-interactive` for scripted environments (must pass all values explicitly).
3. Review generated files (`.devops/`, `.github/workflows/`), commit, and push.
4. Configure GitHub repository secrets with your deployment credentials.
5. Authorize the SSH key on the target server.
6. Run `.devops/scripts/build-local.sh` to confirm the build works.
7. Push to your development branch and let `dev.yml` verify the build.
8. When ready, run `.devops/scripts/release.sh` to promote to production and trigger the deploy workflow.

Quick shortcut: From the repo root you can also use `./devops <command>` (e.g. `./devops push "msg"`, `./devops release`, `./devops update`).

### 📝 Example: PHP Project

For a PHP admin panel (like WordPress, Laravel, or plain PHP):

```bash
/var/code/github-starterpack/scripts/setup-devops.sh \
  --target /var/www/admin.example.com \
  --project-name "Admin Panel" \
  --site-url https://admin.example.com \
  --deploy-path /var/www/admin.example.com
```

**What happens:**
- ✅ Auto-detects PHP files
- ✅ Sets `BUILD_COMMAND="echo '✅ No build needed for PHP application'"`
- ✅ Uses PHP-optimized GitHub Actions (syntax check, rsync deploy)
- ✅ No npm/Node.js requirements

### 📝 Example: Playwright Test Project

For a Playwright E2E test suite:

```bash
/var/code/github-starterpack/scripts/setup-devops.sh \
  --target /var/code/api-e2e-tests \
  --project-name "API E2E Tests" \
  --site-url https://api.example.com
```

**What happens:**
- ✅ Auto-detects `playwright.config.ts`
- ✅ Sets `BUILD_COMMAND="npm test"`
- ✅ Uses test-optimized GitHub Actions workflows:
  - Scheduled tests (daily at 2 AM UTC)
  - Post-deployment tests (triggered by `repository_dispatch`)
  - Manual specific API tests
- ✅ No traditional deployment (tests run in CI only)

---

## 🧰 DevOps Tools

The `devops-tools/` directory contains cross-project utilities for managing and monitoring all repositories:

- **`check-devops-repos.sh`** - Scans all repositories for .devops implementation status
- **`health-check-all.sh`** - Health checks for all deployed servers
- **`sync-devops-config.sh`** - Syncs .devops configs across all repositories

Run from the starterpack root:
```bash
./devops-tools/scripts/check-devops-repos.sh
```

See `devops-tools/README.md` for full documentation.

---

## 🧑‍🤝‍🧑 Customer Project Bootstrap (arkturian.com)

Use `scripts/setup-customer-project.sh` to spin up a full customer project (GitHub repo, CodePilot DB, Nginx/SSL, build + deploy) based on the shared template that already lives on the server.

Local execution on the server:
```bash
./scripts/setup-customer-project.sh --project-name demo1 --customer-email info@demo1.com --customer-name "Demo One"
```

Remote from your Mac (executes over SSH on arkturian.com):
```bash
./scripts/setup-customer-project.sh \
  --project-name demo1 \
  --customer-email info@demo1.com \
  --customer-name "Demo One" \
  --host arkturian.com \
  --ssh-user root
```

Defaults: repo owner `apopovic77`, domain suffix `arkturian.com`, projects root `/var/code`, deploy base `/var/www`, CodePilot DB `codepilot` on `localhost`. Flags let you override these, skip certbot, or choose public repo visibility. The script validates prerequisites (`gh`, `psql`, `nginx`, `certbot`, `npm`, etc.) before making changes.

Notes:
- Use `--repo-name` if the GitHub repo should differ from the domain prefix.
- Use `--domain` to set a custom FQDN (otherwise `<project-name>.<domain-suffix>`).

Cleanup helper:
```bash
./scripts/delete-customer-project.sh \
  --project-name demo1 \
  --repo-name demo1 \
  --domain demo1.arkturian.com \
  --yes
```
Deletes GitHub repo, CodePilot DB records, Nginx vhost, deploy path, and local project.

---

## 🛠️ Command Cheatsheet

Every project gets the raw scripts in `.devops/scripts/` *and* a convenience dispatcher `./devops` at the repo root. Both call the same logic – use whichever you prefer.

| Wrapper command | Underlying script | Purpose |
|-----------------|------------------|---------|
| `./devops checkout <branch>` | `.devops/scripts/checkout-branch.sh` | Cleanly switch to `dev`/`main` (fetch + fast-forward) |
| `./devops push "msg"` | `.devops/scripts/push-dev.sh` | Stage → commit → push to the integration branch |
| `./devops build [--clean]` | `.devops/scripts/build-local.sh` | Run the production build locally |
| `./devops release [--no-build]` | `.devops/scripts/release.sh` | Promote `dev` → `main` and trigger the GitHub Actions deploy |
| `./devops update [options]` | `.devops/scripts/update-devops.sh` | Pull the latest starter-pack templates and reapply (`--starter-path` if needed) |
| `./devops rollback` | `.devops/rollback.sh` | Restore a previous backup on the server |

All commands require a clean working tree unless they explicitly create commits (`push`). If you forget the syntax, run `./devops help`.

---

## ♻️ Updating Existing Projects

When the starter pack evolves, refresh an existing project in-place:

```bash
# In this repo (to pull the latest templates)
git pull

# Reapply templates with the saved configuration
scripts/setup-devops.sh --target /path/to/project --update
```

The installer reads `.devops/starter-config.json` (created on the first run), reapplies the templates, and keeps your previous answers. Review the diff, reconcile any local customisations, run a test release, then commit the update.

---

## 🧠 AI Agent Playbook

When an AI agent is asked to operate a project prepared with this starter pack, follow this script:

1. **Bootstrap** – read `.devops/AGENT_BOOTSTRAP.md` for project-specific paths and branch names.
2. **Sync workspace** – run `.devops/scripts/checkout-branch.sh <dev-branch>` (e.g., `dev`).
3. **Implement changes** – code/test as usual.
4. **Commit & push** – use `.devops/scripts/push-dev.sh "your message"`; it stages everything, commits, and pushes to the development branch.
5. **Release** – invoke `.devops/scripts/release.sh` to fast-forward the main branch, push, and trigger GitHub Actions deployment. Use `--no-build` if a local build should be skipped (not recommended).
6. **Monitor** – `gh run watch` (or `gh run list`) to ensure the `Build & Deploy` workflow succeeds.
7. **Rollback (if required)** – SSH into the server and run `.devops/rollback.sh` to restore a backup.

Always confirm the Git tree is clean before switching branches or releasing—scripts enforce this.

---

## ⚙️ Installer Reference (`setup-devops.sh`)

Run `scripts/setup-devops.sh --help` for full usage. Key options:

| Flag | Description | Default |
|------|-------------|---------|
| `--target` | Project directory that should receive the templates | *(required)* |
| `--project-name` | Friendly name used in docs | Basename of target |
| `--repo-root` | Absolute path used inside scripts | Target directory |
| `--deploy-path` | Destination folder on the server | `/var/www/<slug>` |
| `--site-url` | Public site URL for documentation | `https://example.com` |
| `--dev-branch` | Integration branch | `dev` |
| `--main-branch` | Production branch | `main` |
| `--install-deps` | Command run before build | `npm ci --production=false` |
| `--build-command` | Build command | `npm run build` |
| `--node-version` | Node version for CI | `18` |
| `--web-user` / `--web-group` | Ownership applied to deployed files | `www-data` |
| `--backup-prefix` | Prefix for backup folders | project slug |
| `--non-interactive` | Disable prompts, require all values via flags | `false` |

The script copies templates into `.devops/` and `.github/workflows/`, replaces `{{PLACEHOLDERS}}`, and sets execute permissions on shell scripts.

---

## 🔄 Release Workflow Summary

1. **Development** – commits land on the development branch via feature branches + PRs. `dev.yml` runs on every push/PR.
2. **Release** – `.devops/scripts/release.sh` fast-forwards the production branch from the development branch and pushes to GitHub.
3. **Deployment** – `deploy.yml` runs on `main` (or your configured production branch), builds the project, SSHs into the server, backs up the current deployment, copies the new `dist/`, and sets ownership/permissions.
4. **Verification** – open the site or run `curl` to confirm the new build is live.
5. **Rollback** – use `.devops/rollback.sh` to select a backup (`/var/backups/<prefix>-timestamp`) if necessary.

---

## 🔐 Configuring Secrets

After committing the generated files:

```bash
gh secret set DEPLOY_HOST --body "example.com"
gh secret set DEPLOY_USER --body "deploy"
gh secret set DEPLOY_SSH_KEY --body "$(cat ~/.ssh/deploy_key)"
gh secret set DEPLOY_PORT --body "22"   # optional
```

The private key must have its public counterpart in `/home/<user>/.ssh/authorized_keys` on the server. You can generate a new keypair specifically for GitHub Actions:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/github_actions_deploy -N '' -C 'github-actions'
```

Upload the private key as the secret, append the `.pub` file to `authorized_keys`.

---

## 🛠 Customisation Tips

- Non-Node projects: change default `--install-deps` / `--build-command` during setup (e.g., `yarn install`, `yarn build`, `pnpm build`, `composer install`, `npm run build:ssr`).
- Different deployment directories or backup locations: pass custom `--deploy-path` and `--backup-prefix`.
- Additional workflows: add more templates under `templates/github/workflows/` and re-run the installer (or copy manually).
- Branch naming: the scripts hardcode the names you provide; ensure GitHub branch protection settings match.

### 🔒 Example: Arkturian Transcoding API via Relay Host

Some environments can only be reached from an internal relay. For the transcoding API, deployments flow from GitHub → self-hosted runner on `arkturian.com` → targets behind reverse tunnels:

- Runner directory: `/var/code/actions-runner-transcoding`, service `actions.runner.apopovic77-transcoding_api.arkturian-transcoding.service`.
- Workflow labels: `self-hosted`, `arkturian`, `transcoding` pin the deploy job to that host.
- Reverse tunnels expose `arkserver` (Debian) at `localhost:2223` and the Mac at `localhost:2222` on `arkturian.com`.
- Deploy steps rsync the repo to `/var/code/transcoding_api/` and `/Users/alex/mac_transcoding_api/`, then call `bash ./restart_server.sh` (script bootstraps a venv & installs `requirements.txt` if missing).

💡 Tip: Reuse the same runner and labels for any project that must hop through the tunnels; GitHub-hosted runners cannot reach those ports directly.

---

## ❓ Troubleshooting

### General Issues

- **SSH authentication fails in deploy workflow** – double-check `DEPLOY_SSH_KEY` matches the server's `authorized_keys`, and that `DEPLOY_USER` has permission to access the repo + deploy path.
- **Release script refuses to run** – ensure `git status` is clean; scripts abort when uncommitted changes exist.
- **Workflows not triggering** – confirm the production branch and development branch names in the workflow files match your repository.
- **File permissions wrong on server** – adjust `--web-user` / `--web-group` to match your environment (e.g., `nginx`, `apache`).
- **Need to regenerate templates** – rerun the installer with the same target to overwrite (or delete `.devops/` and `.github/workflows/` first).

### PHP-Specific Issues

- **"npm: command not found" error** – you have Node.js templates on a PHP project. Run `--update` to regenerate with PHP auto-detection, or manually edit `.github/workflows/deploy.yml` to remove Node.js steps.
- **PHP syntax errors in CI** – the dev workflow runs `php -l` on all `.php` files. Fix syntax errors before pushing.
- **Composer dependencies** – if you need `composer install`, override with `--install-deps "composer install --no-dev"` during setup.
- **Wrong project type detected** – force the correct build command with `--build-command "your command"` flag during installation.

---

## 🧾 Appendix

- `scripts/setup-devops.sh` is idempotent; rerunning updates the templates with new values.
- Templates live under `templates/` so you can customise them before or after installation.
- The starter pack itself is a regular Git repository; fork it to keep your own defaults.
- For multi-environment deployments, consider duplicating workflows (e.g., staging vs production) with different secrets and target paths.

Happy shipping! 🚀
