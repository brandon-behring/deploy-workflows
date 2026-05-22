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

jobs:
  deploy:
    uses: brandon-behring/deploy-workflows/.github/workflows/deploy-astro-worker.yml@main
    secrets: inherit
```

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

Book sites whose build needs extra steps should rely on npm `prebuild` hooks
in their own `package.json` rather than overriding `build-command` here.
That keeps the workflow simple and the build logic per-repo.

## Versioning

Currently consumed via `@main`. Once a 2nd consumer repo exists, switch to
tag pins (`@v1`) so a breaking change here cannot silently break every
site:

```yaml
uses: brandon-behring/deploy-workflows/.github/workflows/deploy-astro-worker.yml@v1
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

### Optional GitHub Organization

Create a personal org (e.g., `brandon-behring-org`), transfer deploy repos,
store `CLOUDFLARE_API_TOKEN` / `CLOUDFLARE_ACCOUNT_ID` as org secrets.
After that, new sibling sites need zero per-repo secret setup. The single
highest-leverage simplification once you have 3+ consuming sites.

### Optional template repo

Create `brandon-behring/astro-cf-template` with pre-wired `wrangler.jsonc`,
caller workflow, `package.json` skeleton. "Use this template" → ready-to-
deploy new site.

## Secrets setup (for new consumer repos)

See `brandon-behring/brandon-behring.dev/docs/cloudflare-setup.md` for the
walkthrough: get Account ID, create an "Edit Cloudflare Workers" API token,
run `gh secret set` for `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
