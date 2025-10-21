# DevOps Starter Pack

Automate copying a preconfigured `.devops/` helper suite and GitHub Actions workflows into any project. Run `scripts/setup-devops.sh --target <path>` and follow the prompts to tailor repo paths, deploy folders, branches, and build command. The script populates `.devops/`, `.github/workflows/`, and bootstrap docs; afterwards, add your deployment SSH key as repository secrets (`DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY`, optional `DEPLOY_PORT`) and commit the generated files.
