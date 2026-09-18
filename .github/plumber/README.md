# Plumber

CI/CD security scanning for the GitHub Actions workflows in this repository.
[Plumber](https://getplumber.io) statically analyses `.github/workflows/` for
supply-chain and pipeline misconfigurations: unpinned or unvetted actions,
`secrets: inherit`, missing `permissions:` blocks, dangerous triggers,
template injection, cache poisoning and branch protection gaps.

## Files

| Path | Purpose |
|---|---|
| `.github/plumber/plumber.yaml` | Policy overlay on top of `plumber:default` |
| `.github/plumber/README.md` | This file |
| `.github/workflows/pr.yml` | Advisory PR scan and chart validation |
| `.github/workflows/plumber.yml` | Reusable workflow invoked by the development and release workflows |

## Running it locally

```bash
brew install getplumber/tap/plumber        # or grab the binary from the GitHub releases
plumber analyze --config .github/plumber/plumber.yaml
plumber explain ISSUE-801                  # details for a given issue code
```

`plumber analyze` scans the local workflows and queries the GitHub API for
branch protection. That last control needs a token with `Administration: read`;
without it, protection findings are incomplete rather than wrong.

## Policy

`plumber.yaml` extends `plumber:default` and only adds an allowlist of the
third-party actions this repository already relies on. Each entry names an
exact `owner/repo` rather than an owner wildcard, so trust cannot spread to
other or future repositories under those accounts. Every one of them is
pinned by commit SHA in the workflows.

## Gating

The development workflow and signed-tag release workflow invoke the reusable
Plumber workflow, which also runs weekly. These runs require `min-score: B`
with `soft-fail: false`; results are uploaded to Code Scanning and the score
service.

Pull requests run the pinned action directly with `contents: read` only.
The scan is advisory (`soft-fail: true`, `continue-on-error: true`) and disables
SARIF upload and score publication. `.github/workflows/pr.yml` also runs the
chart validation check, `scripts/validate-chart.sh`. Whether that check is
required for merging depends on repository rules; the exact rule behind the
observed blocked PR state has not been verified.

The publication workflows are not triggered by `pull_request`: development
publishes from `dev`, while production requires a signed `v*` tag and an
approved `release` environment. Attestation verification remains enabled in
both the advisory and reusable scans.

Each run also uploads a `plumber-report` artifact holding the JSON report, the
PBOM, the CycloneDX SBOM and the raw SARIF (`upload-artifacts: true`). The
SARIF is redundant with Code Scanning; the PBOM and SBOM are kept as per-run
evidence of what the pipeline consumed.

## Branch protection

ISSUE-501 (`branch "dev" must be protected`) is a repository setting, not a
file in this repo: `main` is protected, `dev` is not. Until a ruleset covers
`dev`, that Critical finding caps the score at 30/100 and the gate fails.
