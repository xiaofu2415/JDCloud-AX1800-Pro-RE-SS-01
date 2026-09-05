#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

fail() { echo "verify-release: $*" >&2; exit 1; }
if [[ $# -ne 3 ]]; then
  echo "usage: $0 <output-dir> <variant> <version>" >&2
  exit 2
fi

output="$1"
variant="$2"
version="$3"
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
[[ -d "$output" ]] || fail "output directory is missing"
cd "$output"
assets=(
  BUILD-METADATA.txt
  build.config
  "$prefix-initramfs-uImage.itb"
  "$prefix-squashfs-factory.bin"
  "$prefix-squashfs-sysupgrade.bin"
  "$prefix.manifest"
  profiles.json
)
for asset in "${assets[@]}" SHA256SUMS; do
  [[ -f "$asset" && -s "$asset" && ! -L "$asset" ]] || fail "required file is missing, empty or not regular: $asset"
done
# A closed file set also rejects other devices, variants, versions and stale images.
shopt -s nullglob dotglob
entries=(*)
[[ ${#entries[@]} -eq 8 ]] || fail "unexpected release files (device or variant contamination)"

# Check both digest correctness and exact coverage: a valid subset is insufficient.
if command -v sha256sum >/dev/null 2>&1; then
  expected_sums="$(sha256sum "${assets[@]}")"
else
  expected_sums="$(shasum -a 256 "${assets[@]}")"
fi
printf '%s\n' "$expected_sums" | cmp -s - SHA256SUMS || fail "SHA256SUMS mismatch or incomplete coverage"
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c SHA256SUMS
else
  shasum -a 256 -c SHA256SUMS
fi

factory_bytes="$(wc -c < "$prefix-squashfs-factory.bin")"
[[ $((factory_bytes % 65536)) -eq 0 ]] || fail "factory image is not aligned to 65536 bytes"
packages="$(bash "$repo_root/.github/scripts/required-packages.sh" "$variant")"
while IFS= read -r package; do
  awk -v package="$package" '$1 == package { found = 1 } END { exit !found }' "$prefix.manifest" || fail "manifest missing required package: $package"
done <<< "$packages"

awk -F= -v variant="$variant" -v version="$version" -v config="$expected_config" '
  /\r/ || NF < 2 || seen[$1]++ { invalid = 1 }
  $1 == "source_commit" || $1 == "builder_commit" { if (length(substr($0, index($0, "=") + 1)) == 0) invalid = 1; next }
  $1 == "variant" { if ($0 != "variant=" variant) invalid = 1; next }
  $1 == "version" { if ($0 != "version=" version) invalid = 1; next }
  $1 == "config_file" { if ($0 != "config_file=" config) invalid = 1; next }
  { invalid = 1 }
  END { exit (invalid || NR != 5 || !seen["source_commit"] || !seen["builder_commit"] || !seen["variant"] || !seen["version"] || !seen["config_file"]) }
' BUILD-METADATA.txt || fail "invalid build metadata"
