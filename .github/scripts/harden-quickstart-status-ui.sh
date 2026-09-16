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
expected_patched_sha='53c7c01eeacd13dd1483f69e5209bcf1f639dfe44235da6827649f2fcdf9750a'
current_sha="$(sha256sum "$template" | awk '{print $1}')"
if [[ "$current_sha" == "$expected_patched_sha" ]]; then
  [[ "$(grep -Fc 'RE-SS-01 兼容提示' "$template")" == 1 ]]
  exit 0
fi
[[ "$current_sha" == "$expected_original_sha" ]] || {
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
    print "  <p><strong>RE-SS-01 兼容提示：</strong>QuickStart 首页的 CPU 温度和整盘容量可能不准确。</p>"
    print "  <p>CPU/Wi-Fi 温度以 <a href=\"/cgi-bin/luci/admin/status/overview\">标准 LuCI 状态页</a> 为准；可写空间以 <a href=\"/cgi-bin/luci/admin/system/mounts\">挂载点页面</a> 的 <code>/overlay</code> 为准。</p>"
    print "</div>"
    inserted = 1
  }
  { print }
  END { if (!inserted) exit 42 }
' "$template" > "$temporary_file"

patched_sha="$(sha256sum "$temporary_file" | awk '{print $1}')"
[[ "$patched_sha" == "$expected_patched_sha" ]] || {
  echo "QuickStart patch output did not match the reviewed template" >&2
  exit 1
}
mode="$(stat -c '%a' "$template" 2>/dev/null || stat -f '%Lp' "$template")"
chmod "$mode" "$temporary_file"
mv "$temporary_file" "$template"
trap - EXIT HUP INT TERM
