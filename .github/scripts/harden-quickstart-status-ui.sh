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
expected_patched_sha='2f981947da9fb53f16fb634edb4176c837a7572bd68be750b098d8d0b7d7ae3f'
expected_docker_sha='8884c0eddd49ae97aff62f7831b98ac4f4030c41de40d6f60c092b9676d54ccc'
expected_combined_sha='fb27306b284aba2d2434ddd25f194cec18e63cfc46420e4e70e5c160f1e970af'
current_sha="$(sha256sum "$template" | awk '{print $1}')"
if [[ "$current_sha" == "$expected_patched_sha" || "$current_sha" == "$expected_combined_sha" ]]; then
  [[ "$(grep -Fc 'RE-SS-01 兼容提示' "$template")" == 1 ]]
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
  BEGIN { inserted = 0 }
  /^<div id="app">$/ && !inserted {
    print "<div class=\"cbi-section cbi-tsection\">"
    print "  <p><strong>RE-SS-01 兼容提示：</strong>CPU 温度已启用 Qualcomm thermal-zone 兼容适配；整盘容量可能不准确。</p>"
    print "  <p>CPU/Wi-Fi 温度以 <a href=\"/cgi-bin/luci/admin/status/overview\">标准 LuCI 状态页</a> 为准；可写空间以 <a href=\"/cgi-bin/luci/admin/system/mounts\">挂载点页面</a> 的 <code>/overlay</code> 为准。</p>"
    print "</div>"
    inserted = 1
  }
  /<script type="module" crossorigin src="\/luci-static\/quickstart\/index\.js/ && !inserted_adapter {
    print "<script src=\"/luci-static/re-ss-01/quickstart-temperature.js\"></script>"
    inserted_adapter = 1
  }
  { print }
  END { if (!inserted || !inserted_adapter) exit 42 }
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
