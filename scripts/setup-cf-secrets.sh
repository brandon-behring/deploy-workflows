#!/usr/bin/env bash
# setup-cf-secrets.sh — set Cloudflare secrets on a target GitHub repo.
#
# Usage:
#   ./scripts/setup-cf-secrets.sh <owner/repo>
#
# Example:
#   ./scripts/setup-cf-secrets.sh brandon-behring/double_ml_time_series
#
# Reads CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID from $BRANDON_CF_SECRETS_PATH
# (default: ~/.config/brandon-cf-secrets.env). That file is gitignored at the user
# level (~/.config is outside any repo); never commit it.
#
# Idempotent: setting the same value twice via `gh secret set` is a no-op from
# GitHub's perspective (the secret is overwritten with the same value).
#
# Future-track: when cloudflare/wrangler-action#402 ships OIDC support, this
# helper becomes obsolete — switch to OIDC trust relationships and remove the
# CLOUDFLARE_API_TOKEN secret entirely.

set -euo pipefail

REPO="${1:?Usage: $0 <owner/repo>}"
SECRETS_PATH="${BRANDON_CF_SECRETS_PATH:-$HOME/.config/brandon-cf-secrets.env}"

if [[ ! -f "$SECRETS_PATH" ]]; then
  echo "Error: secrets file not found at $SECRETS_PATH" >&2
  echo "" >&2
  echo "Create it (mode 600) with:" >&2
  echo "  CLOUDFLARE_API_TOKEN=<your-token>" >&2
  echo "  CLOUDFLARE_ACCOUNT_ID=<your-account-id>" >&2
  echo "" >&2
  echo "Override the path with BRANDON_CF_SECRETS_PATH=/some/other/path" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$SECRETS_PATH"

: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN not set in $SECRETS_PATH}"
: "${CLOUDFLARE_ACCOUNT_ID:?CLOUDFLARE_ACCOUNT_ID not set in $SECRETS_PATH}"

echo "Setting CF secrets on $REPO..."
gh secret set CLOUDFLARE_API_TOKEN  --repo "$REPO" --body "$CLOUDFLARE_API_TOKEN"
gh secret set CLOUDFLARE_ACCOUNT_ID --repo "$REPO" --body "$CLOUDFLARE_ACCOUNT_ID"

echo ""
echo "Verifying (should show both secrets):"
gh secret list --repo "$REPO" | grep -E "CLOUDFLARE_(API_TOKEN|ACCOUNT_ID)" || {
  echo "Warning: verification grep returned no matches" >&2
  exit 1
}

echo ""
echo "Done. $REPO is ready to consume deploy-workflows."
