#!/usr/bin/env bash
# Tests render-docs/render.sh on the fixture project. Needs Docker and spec-validator on the
# PATH (or VALIDATOR set to a command).
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
render="$here/../render-docs/render.sh"
image=$(sed -n 's/^    default: \(asciidoctor\/.*\)$/\1/p' "$here/../render-docs/action.yml")
work=$(mktemp -d "${TMPDIR:-/tmp}/render.XXXXXX")
trap 'rm -rf "$work"' EXIT
cp -R "$here/fixture/." "$work/"
cd "$work"

VERSION=1.0.0 VALIDATOR="${VALIDATOR:-spec-validator}" IMAGE="$image" OUTPUT=out GITHUB_OUTPUT=github-output "$render"

fail() {
	echo "FAIL $*"
	exit 1
}
for html in specification-web tech-specification-web backlog-web release-notes; do
	[[ -s "out/html/$html.html" ]] || fail "out/html/$html.html is missing"
done
grep -q 'href="backlog-web.html#US-1.1"' out/html/release-notes.html || fail "no link to backlog-web.html#US-1.1"
grep -q 'href="#FR-1.2"' out/html/specification-web.html || fail "no link within specification-web.html"
grep -q 'id="FR-1.2"' out/html/specification-web.html || fail "FR-1.2 has no own id"
grep -q 'src="data:image/png;base64,' out/html/tech-specification-web.html || fail "the diagram is not embedded"
[[ -s out/docs-1.0.0.zip ]] || fail "docs-1.0.0.zip is missing"
[[ ! -d out/flat ]] || fail "out/flat was not removed"
grep -q '^out/docs-1.0.0.zip$' github-output || fail "the zip is not in the files output"
echo "ok   render"
