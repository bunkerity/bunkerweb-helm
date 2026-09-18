# Releasing the Helm chart

Production releases follow the same signed-tag, approval-gated pattern as
`bunkerweb-dev`. CI validates and packages the chart once, creates a draft
GitHub release, then publishes that exact archive to the production chart
repository.

## One-time repository setup

1. Create a GitHub environment named `release` with required reviewers. The
   workflow accepts only `TheophileDiot` and `fl0ppy-d1sk` as reviewers.
2. Add a tag ruleset targeting `v*` that restricts tag creation and updates and
   blocks force pushes.
3. Ensure release operators can create GitHub-verified signed tags.

The workflow fails closed when the environment, required reviewers, verified
tag signature, or tag target cannot be confirmed.

## Cut a release

1. Update `version` and, when needed, `appVersion` in
   `charts/bunkerweb/Chart.yaml`.
2. Add a matching `## vX.Y.Z - YYYY/MM/DD` section to `CHANGELOG.md` and merge
   the release commit to `main`.
3. Create and push a signed annotated tag on that commit:

   ```bash
   git tag -s vX.Y.Z -m vX.Y.Z
   git push origin vX.Y.Z
   ```

4. Review the candidate jobs and approve the `release` environment.
5. After CI publishes the chart archive, review and publish the draft GitHub
   release.

Development publishing remains unchanged: pushes to `dev` validate, package,
and upload a development chart independently.
