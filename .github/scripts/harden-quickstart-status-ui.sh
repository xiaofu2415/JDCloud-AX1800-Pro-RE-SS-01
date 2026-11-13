#!/usr/bin/env bash
set -euo pipefail

package_root="${1:?usage: harden-quickstart-status-ui.sh QUICKSTART_PACKAGE_ROOT}"
template="$package_root/luasrc/view/quickstart/main.htm"

[[ -f "$template" ]] || {
  echo "QuickStart main.htm not found: $template" >&2
  exit 1
}

# Guard the closed upstream template by content, not by a brittle line number.
# The patched digest makes the operation idempotent while still rejecting an
# unrelated upstream change instead of silently editing an unknown page.
expected_original_sha='806d968acb47afadc44f2bcb2c482f7149763a03f83934dc7323a9b95ae85fc2'
expected_patched_sha='267256b0230086778e881df808516876ca9724224485bbcaf2665136647cccf6'
expected_docker_sha='8884c0eddd49ae97aff62f7831b98ac4f4030c41de40d6f60c092b9676d54ccc'
expected_combined_sha='1562ec975ea886c929e9234f99be6b975f709a400462135e28562e7de2e7f05c'
current_sha="$(sha256sum "$template" | awk '{print $1}')"
if [[ "$current_sha" == "$expected_patched_sha" || "$current_sha" == "$expected_combined_sha" ]]; then
  grep -Fq '/luci-static/re-ss-01/quickstart-temperature.js' "$template"
  exit 0
fi
[[ "$current_sha" == "$expected_original_sha" || "$current_sha" == "$expected_docker_sha" ]] || {
  echo "unsupported QuickStart main.htm; refusing an unverified status UI patch" >&2
  exit 1
}

temporary_file="$(mktemp "${template}.XXXXXX")"
cleanup() {
  rm -f "$temporary_file"
}
trap cleanup EXIT HUP INT TERM

awk '
  /<script type="module" crossorigin src="\/luci-static\/quickstart\/index\.js/ && !inserted_adapter {
    print "<script src=\"/luci-static/re-ss-01/quickstart-temperature.js\"></script>"
    inserted_adapter = 1
  }
  { print }
  END { if (!inserted_adapter) exit 42 }
' "$template" > "$temporary_file"

patched_sha="$(sha256sum "$temporary_file" | awk '{print $1}')"
expected_output_sha="$expected_patched_sha"
if [[ "$current_sha" == "$expected_docker_sha" ]]; then
  expected_output_sha="$expected_combined_sha"
fi
[[ "$patched_sha" == "$expected_output_sha" ]] || {
  echo "QuickStart patch output did not match the reviewed template" >&2
  exit 1
}
mode="$(stat -c '%a' "$template" 2>/dev/null || stat -f '%Lp' "$template")"
chmod "$mode" "$temporary_file"
mv "$temporary_file" "$template"
trap - EXIT HUP INT TERM
