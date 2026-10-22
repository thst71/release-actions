#!/usr/bin/env bash
# Tests publish-release/publish.sh in dry-run mode on the fixture project. Needs Docker.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
publish="$here/../publish-release/publish.sh"
image=$(sed -n 's/^    default: \(asciidoctor\/.*\)$/\1/p' "$here/../publish-release/action.yml")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0
cp -R "$here/fixture/." "$work/"
mkdir -p "$work/dist" "$work/other"
echo binary >"$work/dist/tool_1.0.0_linux_amd64.tar.gz"
echo docs >"$work/dist/docs-1.0.0.zip"
echo again >"$work/other/docs-1.0.0.zip"
sed 's/(2026-10-22)/(unreleased)/' "$work/specification/release-notes/1.0.0.adoc" >"$work/undated.adoc"

check() { # version, prerelease, assets, notes, expected output
	local output
	output=$(cd "$work" && DRY_RUN=1 VERSION="$1" PRERELEASE="$2" ASSETS="$3" NOTES="$4" \
		TITLE="" IMAGE="$image" REPOSITORY=thst71/fixture "$publish" 2>&1) || true
	if [[ "$output" != *"$5"* ]]; then
		echo "FAIL $1 '$5', got: $output"
		failures=$((failures + 1))
	else
		echo "ok   $1: $5"
	fi
}

check 1.0.0 false "dist/*" "" "gh release create v1.0.0 --repo thst71/fixture --verify-tag --title fixture\\ 1.0.0"
check 1.0.0 false "dist/*" "" "  tool_1.0.0_linux_amd64.tar.gz"
check 1.0.0 false "dist/*" "" "Greeting with <code>[[ID]]</code> anchors (US-1.1, greet)"
check 1.0.0 true "dist/*" "" "--prerelease"
check 1.0.0 false "" "" "checksums.txt"
check 1.0.0 false "dist/*" "undated.adoc" "must be '== 1.0.0 (YYYY-MM-DD)', not '== 1.0.0 (unreleased)'"
check 2.0.0 false "dist/*" "" "release notes specification/release-notes/2.0.0.adoc are missing"
check 1.0.0 false "dist/*
other/*" "" "two assets are named docs-1.0.0.zip"
check 1.0.0 false "missing/*" "" "no file matches missing/*"
check 1.0.0 false "dist" "" "dist is not a file"

[[ $failures -eq 0 ]] || { echo "$failures failure(s)"; exit 1; }
