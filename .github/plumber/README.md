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
| `.github/workflows/plumber.yml` | Reusable workflow invoked by the `dev` and `prod` workflows |

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

The `dev` and `prod` workflows invoke Plumber directly, and the reusable
workflow also runs weekly. It is gated at `min-score: B` with
`soft-fail: false`, so scores of C, D or E fail the run — no chart is packaged
or published behind a failing scan. Results land in the Code Scanning tab.

Every input is set explicitly in `plumber.yml`, including those that match the
action's own defaults, so that an auditor reads the effective configuration
from the workflow alone and never has to diff it against `action.yml` at some
past tag. `verify-attestation: true` keeps the sigstore/SLSA provenance check
on the downloaded binary; `score-push: true` publishes the score used by the
hosted badge service.

Each run also uploads a `plumber-report` artifact holding the JSON report, the
PBOM, the CycloneDX SBOM and the raw SARIF (`upload-artifacts: true`). The
SARIF is redundant with Code Scanning; the PBOM and SBOM are kept as per-run
evidence of what the pipeline consumed.

## Branch protection

ISSUE-501 (`branch "dev" must be protected`) is a repository setting, not a
file in this repo: `main` is protected, `dev` is not. Until a ruleset covers
`dev`, that Critical finding caps the score at 30/100 and the gate fails.
