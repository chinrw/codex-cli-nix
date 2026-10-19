# Repository settings for automatic updates

Configure these settings in `chinrw/codex-cli-nix` so version updates open pull
requests and merge after the required checks pass.

## Workflow permissions

Under Settings → Actions → General, allow read and write workflow permissions
and allow GitHub Actions to create pull requests.

## Update token

Create the Actions secret `CODEX_UPDATE_TOKEN` with a token that can create
branches and pull requests and enable auto-merge in this repository. The updater
uses this token for pull requests so their events trigger CI. The built-in
`GITHUB_TOKEN` remains sufficient for reading release information and checkout.

## Auto-merge

Enable **Allow auto-merge** under Settings → General → Pull Requests. Keep the
required checks on `main`. The updater requests auto-merge and waits for those
checks instead of merging the version bump immediately.

## Verify an update

Run and inspect the workflow in this fork:

```sh
gh workflow run update.yml --repo chinrw/codex-cli-nix
gh run list --workflow=update.yml --repo chinrw/codex-cli-nix
```

If creating a pull request or enabling auto-merge fails, check the token's access
and expiration, repository workflow permissions, and required checks.

## Cache and tags

Cache publishing is managed separately. This fork does not run the upstream
cache upload or automatic version-tag workflows. The tag utility's tests use
local temporary repositories and do not publish tags.
