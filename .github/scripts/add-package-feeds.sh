#!/usr/bin/env bash
set -euo pipefail

feeds_file="${1:?usage: add-package-feeds.sh FEEDS_CONF VARIANT}"
variant="${2:?usage: add-package-feeds.sh FEEDS_CONF VARIANT}"
test -f "$feeds_file"

case "$variant" in
  argon|istore) ;;
  *)
    echo "unknown feed variant: $variant" >&2
    exit 2
    ;;
esac

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

if [[ "$variant" == "istore" ]]; then
  add_feed istore https://github.com/linkease/istore.git main
  add_feed nas https://github.com/linkease/nas-packages.git master
  add_feed nas_luci https://github.com/linkease/nas-packages-luci.git main
fi
