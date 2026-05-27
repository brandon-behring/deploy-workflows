# deploy-workflows

Reusable GitHub Actions workflows for deploying Astro static sites to
Cloudflare Workers (Static Assets).

## What it provides

`deploy-astro-worker.yml` — a `workflow_call` reusable workflow that:
- Checks out the calling repo
- Installs Node.js (configurable major version)
- Runs `npm ci` and `npm run <build-command>` (configurable, defaults to `build`)
- Deploys via `cloudflare/wrangler-action@v3` using `wrangler deploy`

## Consuming this workflow

In any repo that wants to deploy an Astro static site to Cloudflare Workers,
create `.github/workflows/deploy.yml`:

```yaml
name: Deploy

on:
  push:
    branches: [main]

permissions:
  contents: read
  deployments: write
  actions: read

jobs:
  deploy:
    uses: brandon-behring/deploy-workflows/.github/workflows/deploy-astro-worker.yml@v1
    secrets: inherit
```

> **Why the explicit `permissions:` block?** The reusable workflow declares
> its own `permissions:` minimums (`contents: read`, `deployments: write`).
> When the caller omits a `permissions:` block, GitHub uses the repository's
> default `GITHUB_TOKEN` permissions, which on newer repos can be too narrow
> to satisfy the reusable workflow's declared needs — producing a
> `startup_failure` with the unhelpful message *"This run likely failed
> because of a workflow file issue."* Declaring the three permissions above
> in the caller fixes it. `actions: read` covers cross-repo reusable-workflow
> resolution; `contents: read` covers the checkout; `deployments: write`
> covers the GitHub Deployments API surface the reusable workflow uses.

The consuming repo must have:

- A `wrangler.jsonc` (or `.toml`) at the root defining `name`,
  `compatibility_date`, and `[assets].directory`. Example:

  ```jsonc
  {
    "$schema": "node_modules/wrangler/config-schema.json",
    "name": "brandon-behring",
    "compatibility_date": "2026-05-21",
    "assets": { "directory": "./dist" }
  }
  ```

- An `npm run build` (or your chosen build command) that produces output at
  the asset directory.

- Two GitHub Actions secrets set on the repo: `CLOUDFLARE_API_TOKEN` and
  `CLOUDFLARE_ACCOUNT_ID`.

## Inputs

| Input | Type | Default | Notes |
|---|---|---|---|
| `node-version` | string | `'22'` | Node major version for `actions/setup-node@v4` |
| `build-command` | string | `'build'` | npm script name to run for the build step |
| `working-directory` | string | `'.'` | Subdirectory containing `package.json` + wrangler config (monorepo support; e.g. `'web'`) |
| `validate-command` | string | `''` | Optional npm script run between `npm ci` and build (e.g. `'validate'` for book-scaffold cite-key checks). Empty = skipped |
| `apt-packages` ★ v2 | string | `''` | Space-separated apt packages installed via `apt-get -y` before `npm ci`. Empty = skipped. Example: `'pandoc texlive-base pdf2svg'` |
| `enable-pr-previews` ★ v2 | boolean | `false` | When true, adds a `pull_request` job that runs `wrangler versions upload` and posts the preview URL as a PR comment. Caller must declare `pull_request:` trigger + `pull-requests: write` permission |

Book sites whose build needs extra steps should rely on npm `prebuild` hooks
in their own `package.json` rather than overriding `build-command` here.
That keeps the workflow simple and the build logic per-repo.

### apt-packages (v2)

For sites that need system binaries during the build (pandoc, LaTeX,
poppler tools, etc.). Skipped when empty. Runs in both the production
and preview jobs.

dlai-style caller using apt-packages:

```yaml
jobs:
  deploy:
    uses: brandon-behring/deploy-workflows/.github/workflows/deploy-astro-worker.yml@v2
    secrets: inherit
    with:
      apt-packages: "pandoc texlive-base texlive-latex-extra texlive-pictures pdf2svg poppler-utils"
      validate-command: validate
```

### enable-pr-previews (v2)

Extracts the `double_ml_time_series` preview-on-PR pattern as an opt-in.
When true, opens PRs trigger a `wrangler versions upload` (not deploy)
and a bot comment with the preview URL. Worker versions accumulate;
clean them manually via the CF dashboard if they pile up.

DML-style caller using enable-pr-previews:

```yaml
name: Deploy

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

permissions:
  contents: read
  deployments: write
  actions: read
  pull-requests: write   # required when enable-pr-previews: true

jobs:
  deploy:
    uses: brandon-behring/deploy-workflows/.github/workflows/deploy-astro-worker.yml@v2
    secrets: inherit
    with:
      working-directory: web
      validate-command: ci:validate
      enable-pr-previews: true
```

## Versioning

Use tag pins, not `@main`:

- **`@v1`** — current stable (Phase 1d, 2026-05-26). All 3 portfolio
  consumers (`brandon-behring.dev`, `double_ml_time_series`,
  `ssm-foundations`) pin here. Currently at `v1.0.1` (Node 24 opt-in
  patch). Force-moveable on patch releases.
- **`@v1.0.0`** / **`@v1.0.1`** — immutable point-in-time pins; use only
  if you specifically need to bisect or freeze.
- **`@v2`** — adds `apt-packages` + `enable-pr-previews`. Future
  consumers (dlai, post_transformers, etc.) start here.
- **`@v2.0.0`** — immutable point-in-time pin.

Convention follows `actions/checkout@v4` / `cloudflare/wrangler-action@v3`:
moveable major-line floating tag + immutable semver tags for the same
commits. Patches that fix bugs (e.g., `v1.0.1`) force-move `v1` so all
v1 consumers auto-pick-up on next CI.

```yaml
uses: brandon-behring/deploy-workflows/.github/workflows/deploy-astro-worker.yml@v2
```

## First consumer

`brandon-behring/brandon-behring.dev` (the portfolio site). Live at
<https://brandon-behring.dev>.

## Phase 2 roadmap

Sites currently using one-off deploy configurations that should migrate to
this reusable workflow:

### `post_transformers/guides/web` (already Workers Static Assets, manual deploy)

- Add `.github/workflows/deploy.yml` calling this reusable workflow.
- Set the two secrets in that repo.
- Move custom domain from
  `post-transformers-guide.brandon-m-behring.workers.dev` to
  `post-transformers-guide.brandon-behring.dev`.
- Rename Worker from `post-transformers-guide` to
  `brandon-behring-post-transformers-guide` (person-prefixed naming
  convention shared across all sites).

### `dlai-study-notes` (currently Cloudflare Pages)

- Add `wrangler.jsonc` with `name: "brandon-behring-study-notes"`,
  `compatibility_date`, `[assets] directory = "./dist"`.
- Replace `wrangler pages deploy ...` in its workflow with the caller above.
- Re-bind `study-notes.brandon-behring.dev` from Pages to Workers
  (coordinate the documented 2–5 s switchover; Cloudflare does not allow
  simultaneous Pages + Worker attachments on one domain).

### `book-template-astro` and future books built on `book-scaffold-astro`

- Same pattern: add `wrangler.jsonc`, add caller workflow, set secrets.

### Optional improvements to this workflow (add only if pain emerges)

- `working-directory` input for monorepo-nested sites.
- `wrangler-config-path` input for non-root wrangler configs.
- `custom-domain` input that calls
  `PUT /accounts/{id}/workers/domains` to bind custom domains
  programmatically (eliminates the dashboard click; idempotent).
- `worker-name` input override.

### ~~Optional GitHub Organization~~ (considered and skipped)

Previously suggested as the way to share secrets across repos. On second
look the cost (URL churn on every repo, redirect-but-not-canonical
breakage of external references, irreversible-ish org naming) outweighs
the benefit (~2 minutes of `gh secret set` saved over the project
lifetime) for a solo developer. Most successful solo developers
(simonw, karpathy, antirez, antirez) keep everything under their
personal account. Instead, use the `scripts/setup-cf-secrets.sh`
helper documented below — it captures the secret-management convenience
without the org overhead.

### Optional template repo

Create `brandon-behring/astro-cf-template` with pre-wired `wrangler.jsonc`,
caller workflow, `package.json` skeleton. "Use this template" → ready-to-
deploy new site.

### Future: migrate to OIDC

When [cloudflare/wrangler-action#402](https://github.com/cloudflare/wrangler-action/issues/402)
ships OIDC auth support, this reusable workflow should be updated to
request a short-lived Cloudflare token via OIDC instead of consuming the
`CLOUDFLARE_API_TOKEN` secret. No long-lived secret stored anywhere; one
trust relationship configured once in CF dashboard. Bump to `@v3` when
that lands; consumers upgrade and drop the secret.

## Secrets setup (for new consumer repos)

Two options:

**Manual (one-shot):** see `brandon-behring/brandon-behring.dev/docs/cloudflare-setup.md`
for the walkthrough: get Account ID, create an "Edit Cloudflare Workers" API
token, run `gh secret set` for `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.

**Helper (scriptable, recommended for multi-repo work):** use the included
`scripts/setup-cf-secrets.sh`:

```bash
./scripts/setup-cf-secrets.sh brandon-behring/<repo>
```

The helper reads `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` from
`~/.config/brandon-cf-secrets.env` (override with `BRANDON_CF_SECRETS_PATH=...`)
and runs `gh secret set` for both. Idempotent — safe to re-run.

Create `~/.config/brandon-cf-secrets.env` once (mode 600 recommended):

```
CLOUDFLARE_API_TOKEN=<your-token>
CLOUDFLARE_ACCOUNT_ID=<your-account-id>
```

Then setting up a new consumer repo is one command.
