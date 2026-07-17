#!/bin/bash

# =============================================================================
# BunkerWeb Helm Chart Publish Script
# =============================================================================
# Packages the Helm chart and pushes it to the BunkerWeb chart repo.
# Shared by the dev and prod deploy workflows; they differ only in target env.
#
# Usage: publish-chart.sh <env>   (env is "dev" or "prod")
# Requires: REPO_BEARER_TOKEN in the environment. Run from the repo root.

set -euo pipefail

chart_env="${1:?Usage: $0 <env>}"

cd ./charts
out_dir="$(mktemp -d)"
helm package ./bunkerweb/ --destination "$out_dir"
chart_file="$(find "$out_dir" -maxdepth 1 -type f -name '*.tgz' -print -quit)"
curl --fail-with-body --show-error --silent --request POST \
    --header "Authorization: Bearer ${REPO_BEARER_TOKEN}" \
    --form "env=${chart_env}" \
    --form "chart=@${chart_file};type=application/gzip" \
    "https://repo.bunkerweb.io/api/chart"
