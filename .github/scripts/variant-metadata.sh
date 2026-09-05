#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ( "$1" != "argon" && "$1" != "istore" ) ]]; then
  echo "usage: $0 <argon|istore>" >&2
  exit 2
fi

variant="$1"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
version_file="$repo_root/versions/$variant.version"

if [[ ! -f "$version_file" ]]; then
  echo "missing version file: versions/$variant.version" >&2
  exit 1
fi

version_line_count=0
version=""
while IFS= read -r line || [[ -n "$line" ]]; do
  ((version_line_count += 1))
  version="$line"
done < "$version_file"
if [[ $version_line_count -ne 1 ]]; then
  echo "version must contain exactly one line" >&2
  exit 1
fi

if [[ -z "$version" || "$version" =~ [[:space:]] || ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]]; then
  echo "invalid version: $version" >&2
  exit 1
fi

case "$variant" in
  argon)
    config_file="configs/re-ss-01-argon.config"
    release_title="京东云 AX1800 PRO（RE-SS-01）· Argon v$version"
    prerelease="false"
    ;;
  istore)
    config_file="configs/re-ss-01-istore.config"
    release_title="京东云 AX1800 PRO（RE-SS-01）· iStoreOS Dashboard v$version"
    prerelease="true"
    ;;
esac

tag="re-ss-01-$variant-v$version"
artifact_name="jdcloud-re-ss-01-libwrt-$variant-v$version"

printf '%s\n' \
  "variant=$variant" \
  "config_file=$config_file" \
  "version=$version" \
  "tag=$tag" \
  "artifact_name=$artifact_name" \
  "release_title=$release_title" \
  "prerelease=$prerelease"
