#!/usr/bin/env bash
set -euo pipefail

feeds_file="${1:?usage: add-package-feeds.sh FEEDS_CONF}"
test -f "$feeds_file"

add_feed() {
  local name="$1"
  local url="$2"
  local branch="$3"

  grep -Eq "^src-git ${name}[[:space:]]" "$feeds_file" && return 0
  printf 'src-git %s %s;%s\n' "$name" "$url" "$branch" >> "$feeds_file"
}

add_feed passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git main
add_feed passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git main
add_feed mosdns https://github.com/sbwml/luci-app-mosdns.git v5
