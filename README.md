# CI/CD: GitHub Actions → Azure VMs (via Bastion)

Deploys the static site in `src/` to `vm-app-01` and `vm-app-02` (the VMs from
the End-to-End Azure Architecture guide) every time a PR is merged into `main`.

## How it works

1. Open a PR → `.github/workflows/deploy.yml`'s **validate** job runs a basic
   HTML sanity check. Nothing touches Azure at this stage.
2. Merge the PR → the **deploy** job runs on push to `main`:
   - Logs into Azure with OIDC (no stored client secret)
   - Opens a tunnel to each VM through Azure Bastion
   - Copies `src/` onto the VM and reloads Nginx
   - Curls the Load Balancer's public IP to confirm the site is live

## One-time setup

1. Confirm `bas-app-prod` is **Standard SKU** Bastion (native-client tunneling
   requires Standard or Premium — Basic SKU won't work). The architecture
   guide's Step 10 already creates it as Standard.
2. Run `./setup-azure-oidc.sh` (edit the variables at the top first) — it
   creates the Entra ID app registration, federated credential, role
   assignment, and pushes a dedicated SSH key onto both VMs.
3. Add the four secrets it prints out to **GitHub → Settings → Secrets and
   variables → Actions**.
4. Push this repo (including `.github/workflows/deploy.yml`) to GitHub.
5. Open a PR that changes `src/index.html`, merge it, and watch the **Actions**
   tab — the deploy job should go green and the Load Balancer's public IP
   should serve your change within a minute or two.

See `Azure_GitHub_Actions_CICD_Guide.docx` for the full walkthrough with
Azure Portal click-through equivalents of every CLI step.
