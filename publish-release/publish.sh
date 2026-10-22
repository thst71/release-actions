#!/usr/bin/env bash
# Publishes the release v$VERSION: checks that the release notes are dated and name the
# agent-skills version of the build, renders them as the release text, writes checksums.txt over
# the assets and calls gh release create. DRY_RUN=1 prints the gh call instead.
set -euo pipefail

fail() {
	echo "::error::$*" >&2
	exit 1
}

notes=${NOTES:-specification/release-notes/$VERSION.adoc}
[[ -f "$notes" ]] || fail "release notes $notes are missing"
heading=$(grep -m 1 '^== ' "$notes" || true)
[[ "$heading" == "== Release v$VERSION ("[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]")" ]] ||
	fail "the first heading of $notes must be '== Release v$VERSION (YYYY-MM-DD)', not '$heading'"

# The vendored agent-skills library knows its version since vendor.sh writes it.
library=${LIBRARY_VERSION_FILE:-.agents/skills/VERSION}
if [[ -f "$library" ]]; then
	built="Built with agent-skills v$(tr -d ' \r\n' <"$library")."
	grep -qxF "$built" "$notes" || fail "$notes must contain the line '$built'"
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# The title carries the version; references become their IDs or texts.
awk 'done || !/^== / { print; next } { done = 1 }' "$notes" |
	sed -E 's/<<[^,>]+,([^>]*)>>/\1/g; s/<<([^>]+)>>/\1/g' >"$work/notes.adoc"
docker run --rm -u "$(id -u):$(id -g)" -v "$work:/w" -w /w "$IMAGE" \
	asciidoctor -s -a showtitle! -o notes.html notes.adoc

shopt -s nullglob
attachments=()
while IFS= read -r pattern; do
	[[ -z "$pattern" ]] && continue
	# shellcheck disable=SC2206 # the pattern is a glob
	matches=($pattern)
	[[ ${#matches[@]} -gt 0 ]] || fail "no file matches $pattern"
	for match in "${matches[@]}"; do
		[[ -f "$match" ]] || fail "$match is not a file"
	done
	attachments+=("${matches[@]}")
done <<<"$ASSETS"

duplicate=$(for asset in ${attachments[@]+"${attachments[@]}"}; do basename "$asset"; done | sort | uniq -d | head -n 1)
[[ -z "$duplicate" ]] || fail "two assets are named $duplicate"
: >"$work/checksums.txt"
for asset in ${attachments[@]+"${attachments[@]}"}; do
	name=$(basename "$asset")
	if command -v sha256sum >/dev/null; then
		sum=$(sha256sum "$asset" | cut -d ' ' -f 1)
	else
		sum=$(shasum -a 256 "$asset" | cut -d ' ' -f 1)
	fi
	printf '%s  %s\n' "$sum" "$name" >>"$work/checksums.txt"
done

command=(gh release create "v$VERSION" --repo "$REPOSITORY" --verify-tag
	--title "${TITLE:-${REPOSITORY#*/} $VERSION}" --notes-file "$work/notes.html")
[[ "$PRERELEASE" == true ]] && command+=(--prerelease)
command+=(${attachments[@]+"${attachments[@]}"} "$work/checksums.txt")
if [[ -n "${DRY_RUN:-}" ]]; then
	printf '%q ' "${command[@]}"
	echo
	cat "$work/checksums.txt" "$work/notes.html"
else
	"${command[@]}"
fi
