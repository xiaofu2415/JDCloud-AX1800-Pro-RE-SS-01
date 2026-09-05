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

file_mode() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

add_exact_feed() {
  local name="$1"
  local url="$2"
  local branch="$3"
  local line="src-git ${name} ${url};${branch}"
  local exact_count
  local name_count
  local original_mode
  local temporary_file

  exact_count="$(grep -Fxc "$line" "$feeds_file" || true)"
  name_count="$(grep -Ec "^src-git ${name}[[:space:]]" "$feeds_file" || true)"
  if [[ "$exact_count" -eq 1 && "$name_count" -eq 1 ]]; then
    return 0
  fi

  original_mode="$(file_mode "$feeds_file")"
  temporary_file="$(mktemp "${feeds_file}.XXXXXX")"
  awk -v name="$name" '$0 !~ ("^src-git " name "[[:space:]]")' "$feeds_file" > "$temporary_file"
  printf '%s\n' "$line" >> "$temporary_file"
  chmod "$original_mode" "$temporary_file"
  mv "$temporary_file" "$feeds_file"
}

add_feed passwall_packages https://github.com/xiaorouji/openwrt-passwall-packages.git main
add_feed passwall2 https://github.com/Openwrt-Passwall/openwrt-passwall2.git main
add_feed mosdns https://github.com/sbwml/luci-app-mosdns.git v5

if [[ "$variant" == "istore" ]]; then
  add_exact_feed istore https://github.com/linkease/istore.git main
  add_exact_feed nas https://github.com/linkease/nas-packages.git master
  add_exact_feed nas_luci https://github.com/linkease/nas-packages-luci.git main
fi
