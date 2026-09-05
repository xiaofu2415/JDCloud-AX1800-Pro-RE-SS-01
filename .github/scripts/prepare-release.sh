#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

fail() { echo "prepare-release: $*" >&2; exit 1; }
if [[ $# -ne 7 ]]; then
  echo "usage: $0 <target-dir> <output-dir> <variant> <version> <source-commit> <builder-commit> <config-path>" >&2
  exit 2
fi

target="$1"
output="$2"
variant="$3"
version="$4"
source_commit="$5"
builder_commit="$6"
config="$7"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
metadata="$(bash "$repo_root/.github/scripts/variant-metadata.sh" "$variant")"
expected_version=""
expected_config=""
prefix=""
while IFS='=' read -r key value; do
  case "$key" in
    version) expected_version="$value" ;;
    config_file) expected_config="$value" ;;
    artifact_name) prefix="$value" ;;
  esac
done <<< "$metadata"
[[ "$version" == "$expected_version" ]] || fail "version does not match variant metadata"
[[ "$config" == "$expected_config" ]] || fail "config does not match variant metadata"
for commit in "$source_commit" "$builder_commit"; do
  [[ -n "$commit" && "$commit" != *$'\n'* && "$commit" != *$'\r'* ]] || fail "commit must be a non-empty single line"
done
[[ -d "$target" ]] || fail "target directory is missing"
[[ -f "$repo_root/$config" && -s "$repo_root/$config" ]] || fail "selected config is missing or empty"

# Match a complete device token and image purpose; never choose the first glob hit.
shopt -s nullglob dotglob
suffixes=(-squashfs-factory.bin -squashfs-sysupgrade.bin -initramfs-uImage.itb .manifest)
sources=()
for suffix in "${suffixes[@]}"; do
  matches=("$target"/*-jdcloud_re-ss-01"$suffix")
  [[ ${#matches[@]} -eq 1 ]] || fail "expected exactly one RE-SS-01 $suffix file"
  [[ -f "${matches[0]}" && -s "${matches[0]}" && ! -L "${matches[0]}" ]] || fail "input is not a non-empty regular file: ${matches[0]}"
  sources+=("${matches[0]}")
done
[[ -f "$target/profiles.json" && -s "$target/profiles.json" && ! -L "$target/profiles.json" ]] || fail "profiles.json is missing or empty"

# Keep caller-owned output intact. An existing empty directory is allowed.
[[ -n "$output" && ! -L "$output" ]] || fail "invalid output directory"
if [[ -e "$output" ]]; then
  [[ -d "$output" ]] || fail "output exists and is not a directory"
  entries=("$output"/*)
  [[ ${#entries[@]} -eq 0 ]] || fail "output directory must be empty"
fi
mkdir -p "$(dirname "$output")"
parent="$(cd "$(dirname "$output")" && pwd)"
output="$parent/$(basename "$output")"
stage="$(mktemp -d "$parent/.release.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
for ((index = 0; index < ${#suffixes[@]}; index++)); do
  cp "${sources[$index]}" "$stage/$prefix${suffixes[$index]}"
done
cp "$target/profiles.json" "$stage/profiles.json"
cp "$repo_root/$config" "$stage/build.config"
printf '%s\n' \
  "source_commit=$source_commit" \
  "builder_commit=$builder_commit" \
  "config_file=$config" \
  "variant=$variant" \
  "version=$version" > "$stage/BUILD-METADATA.txt"

# The checksum manifest is generated last, using only relative, sorted filenames.
(
  cd "$stage"
  assets=(*)
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${assets[@]}" > SHA256SUMS
  else
    shasum -a 256 "${assets[@]}" > SHA256SUMS
  fi
)
bash "$repo_root/.github/scripts/verify-release.sh" "$stage" "$variant" "$version"
if [[ -d "$output" ]]; then
  rmdir "$output"
fi
mv "$stage" "$output"
trap - EXIT
