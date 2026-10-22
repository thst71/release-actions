#!/usr/bin/env bash
# Verifies that TAG is a release tag: named v<semver>, annotated, SSH-signed by a principal of
# ALLOWED_SIGNERS, and that principal is the tagger. Writes version and prerelease to
# GITHUB_OUTPUT.
set -euo pipefail

fail() {
	echo "::error::$*" >&2
	exit 1
}

[[ -n "${ALLOWED_SIGNERS:-}" ]] ||
	fail "no allowed signers: set the secret RELEASE_ALLOWED_SIGNERS in the environment 'release'"
semver='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'
[[ "$TAG" =~ $semver ]] || fail "$TAG is not a release tag (v<major>.<minor>.<patch>[-pre][+build])"

# actions/checkout may have replaced the annotated tag with a lightweight one.
git fetch --quiet --force origin "refs/tags/$TAG:refs/tags/$TAG"
[[ "$(git cat-file -t "refs/tags/$TAG")" == tag ]] || fail "$TAG is not an annotated tag"
git cat-file -p "refs/tags/$TAG" | grep -q '^-----BEGIN SSH SIGNATURE-----$' ||
	fail "$TAG is not signed with an SSH key"

signers=$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/allowed_signers.XXXXXX")
trap 'rm -f "$signers"' EXIT
printf '%s\n' "$ALLOWED_SIGNERS" >"$signers"
if ! output=$(git -c gpg.ssh.allowedSignersFile="$signers" verify-tag "$TAG" 2>&1); then
	fail "$TAG is not signed by an allowed signer: $output"
fi
principal=$(sed -n 's/^Good "git" signature for \(.*\) with .* key .*$/\1/p' <<<"$output")
tagger=$(git for-each-ref --format='%(taggeremail:trim)' "refs/tags/$TAG")
[[ "$principal" == "$tagger" ]] || fail "$TAG is signed by $principal but tagged by $tagger"

version=${TAG#v}
core=${version%%+*}
prerelease=false
[[ "$core" == *-* ]] && prerelease=true
{
	echo "version=$version"
	echo "prerelease=$prerelease"
} >>"${GITHUB_OUTPUT:-/dev/stdout}"
echo "$TAG is signed by $principal"
