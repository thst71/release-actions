# release-actions

GitHub Actions for releasing from a signed tag, as the `release` skill of
[agent-skills](https://github.com/thst71/agent-skills) describes it: sign a tag locally, push
it, and the pipeline does the rest. No click on github.com.

| Action | Does |
|---|---|
| [`verify-release-tag`](verify-release-tag/action.yml) | Fails unless the tag is `v<semver>`, annotated and SSH-signed by an allowed signer who is the tagger. Outputs `version` and `prerelease`. |
| [`render-docs`](render-docs/action.yml) | Renders every master of the modular AsciiDoc specification into one HTML file, with links between the masters, plus `docs-<version>.zip`. |
| [`publish-release`](publish-release/action.yml) | Creates the release from the dated release notes, with the assets and a `checksums.txt` over them. |

## How a Release Works

1. Locally: date the release notes (`== 1.2.0 (2026-10-22)`), commit, then `git tag -a v1.2.0 -m "…"` (signed automatically with `tag.gpgSign = true`) and `git push origin main v1.2.0`.
2. The release workflow starts for tags matching `v[0-9]+.[0-9]+.[0-9]+*`; all other tags are free for other uses.
3. `verify` (environment `release`) checks the signature against the secret `RELEASE_ALLOWED_SIGNERS`; the project's build, the gate and `render-docs` follow; `publish` (environment `release`, `contents: write`) creates the release.

The workflow template and the one-time repository setup (environment, secret, tag ruleset) are part of the agent-skills `release` skill.

## Allowed Signers

The actions hold no keys. Each repository stores an OpenSSH `allowed_signers` content as the secret `RELEASE_ALLOWED_SIGNERS` of the environment `release`, for example:

```
thst@strauss-it.de namespaces="git" ssh-ed25519 AAAAC3Nz…
```

Only the public key is needed. The environment admits release tags only, so no other job and no other ref can read it. A tag ruleset on `refs/tags/v[0-9]*` lets only repository admins create, move or delete release tags: the workflow file runs from the tagged commit, so the ruleset, not the signature check, keeps others from releasing.

## Pinning

Reference the actions by full commit SHA with the version as a comment:

```yaml
- uses: thst71/release-actions/verify-release-tag@<sha> # v0.1.0
```

## Development

`task check` runs actionlint, shellcheck, the tests and the specification validation. The render and publish tests need Docker; the render test needs `spec-validator` on the `PATH`. The scripts run with bash 3.2 and 5.

Windows is nice to have here too:

> "Is Windows a real target or just nice to have?" – Claude
>
> "Windows is nice to have, quote me quoting you in the readme :-)" – Thomas Strauß

(The actions run on Linux runners; Windows does not matter for them.)

## License

[LGPL-3.0-only](COPYING.LESSER) (which builds on the [GPL-3.0](COPYING)).
