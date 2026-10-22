# §1 Needs

1. Releasing happens offline: the maintainer signs a tag locally and pushes it; no click on
   github.com.
2. Tags also serve other purposes. Only tags named `v<semver>` are releases.
3. A release tag must be annotated and SSH-signed by the maintainer (1Password serves the key).
   Unsigned tags, other signers and lightweight tags fail visibly; nothing is published.
4. The allowed signers are not stored in any repository, so the actions are reusable as they
   are. Each repository holds them as the secret `RELEASE_ALLOWED_SIGNERS` of the environment
   `release`, readable only by release jobs on release tags.
5. A release carries the full documentation: every master of the specification as one HTML
   file, with links between the masters, and all of them as a zip.
6. The release text is the version's release notes; notes still marked `(unreleased)` stop the
   release. A `checksums.txt` covers all assets.
7. Release notes are read as a web page. Their headings say `Release v<version> (<date>)`
   without chapter numbers ("2. 0.1.0" was easy to misread), and each version names the
   agent-skills version it was built with.
