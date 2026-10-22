#!/usr/bin/env bash
# Tests verify-release-tag/verify.sh against a repository with tags signed by throw-away keys.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
verify="$here/../verify-release-tag/verify.sh"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

ssh-keygen -q -t ed25519 -N '' -C me -f "$work/me"
ssh-keygen -q -t ed25519 -N '' -C other -f "$work/other"
git init -q "$work/repo"
cd "$work/repo"
git config user.name Me
git config user.email me@example.org
git config gpg.format ssh
git config gpg.ssh.program ssh-keygen
git config tag.gpgSign false
git config commit.gpgSign false
git commit -q --allow-empty -m init
git remote add origin "$work/repo"

signed() { # key, tag
	git -c user.signingkey="$work/$1" tag -s "$2" -m "$2"
}
signed me v1.0.0
signed me v1.1.0-rc.1
signed me v1.2.0+build-1
git tag -a v2.0.0 -m unsigned
git tag v3.0.0
signed other v4.0.0
git -c user.email=other@example.org -c user.signingkey="$work/me" tag -s v5.0.0 -m v5.0.0
signed me v6.0
allowed="me@example.org namespaces=\"git\" $(cat "$work/me.pub")"

check() { # tag, allowed signers, expected output
	local output
	output=$(TAG="$1" ALLOWED_SIGNERS="$2" GITHUB_OUTPUT=/dev/stdout "$verify" 2>&1) || true
	if [[ "$output" != *"$3"* ]]; then
		echo "FAIL $1: want '$3', got: $output"
		failures=$((failures + 1))
	else
		echo "ok   $1: $3"
	fi
}

check v1.0.0 "$allowed" "prerelease=false"
check v1.0.0 "$allowed" "v1.0.0 is signed by me@example.org"
check v1.1.0-rc.1 "$allowed" "prerelease=true"
check v1.2.0+build-1 "$allowed" "prerelease=false"
check v2.0.0 "$allowed" "v2.0.0 is not signed with an SSH key"
check v3.0.0 "$allowed" "v3.0.0 is not an annotated tag"
check v4.0.0 "$allowed" "v4.0.0 is not signed by an allowed signer"
check v5.0.0 "$allowed" "v5.0.0 is signed by me@example.org but tagged by other@example.org"
check v6.0 "$allowed" "v6.0 is not a release tag"
check v1.0.0 "" "no allowed signers"

[[ $failures -eq 0 ]] || { echo "$failures failure(s)"; exit 1; }
