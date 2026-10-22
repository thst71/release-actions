#!/usr/bin/env bash
# Renders each master of the specification in the working directory into one HTML file:
# asciidoctor-reducer flattens the master, spec-validator -link turns references to other
# masters into xrefs, asciidoctor renders with embedded images and fails on any warning or
# unresolved reference. Writes the file list to GITHUB_OUTPUT.
set -euo pipefail

read -r -a validator <<<"$VALIDATOR"
masters=()
while IFS= read -r master; do
	[[ -n "$master" ]] && masters+=("$master")
done < <("${validator[@]}" -masters)
[[ ${#masters[@]} -gt 0 ]] || { echo "::error::spec-validator lists no masters" >&2; exit 1; }

rm -rf "$OUTPUT"
mkdir -p "$OUTPUT/flat" "$OUTPUT/html"
out=$(cd "$OUTPUT" && pwd)
docker_run() {
	docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
		-v "$PWD:/src:ro" -v "$out:/out" -w /src "$IMAGE" "$@"
}

for master in "${masters[@]}"; do
	mkdir -p "$out/flat/$(dirname "$master")" "$out/html/$(dirname "$master")"
	docker_run asciidoctor-reducer -o "/out/flat/$master" "$master"
done
"${validator[@]}" -link "$out/flat"

files=()
for master in "${masters[@]}"; do
	html="${master%.adoc}.html"
	docker_run asciidoctor -r asciidoctor-diagram -a data-uri -a revnumber="$VERSION" \
		-a imagesoutdir=/tmp/diagrams -a diagram-cachedir=/tmp/diagram-cache \
		-v --failure-level INFO -B "/src/$(dirname "$master")" \
		-o "/out/html/$html" "/out/flat/$master"
	files+=("$OUTPUT/html/$html")
done

(cd "$out/html" && zip -qr "../docs-$VERSION.zip" .)
files+=("$OUTPUT/docs-$VERSION.zip")
rm -rf "$out/flat"
{
	echo "files<<EOF_FILES"
	printf '%s\n' "${files[@]}"
	echo "EOF_FILES"
} >>"${GITHUB_OUTPUT:-/dev/stdout}"
