#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <argon|istore>" >&2
  exit 2
fi

variant="$1"
common_packages=(
  luci-app-passwall2
  luci-app-mosdns
  luci-app-adguardhome
  luci-app-nlbwmon
  luci-app-dockerman
  tailscale
  luci-app-sqm
  sqm-scripts-nss
  luci-theme-argon
  luci-theme-bootstrap
  luci-i18n-base-zh-cn
)

case "$variant" in
  argon)
    printf '%s\n' "${common_packages[@]}"
    ;;
  istore)
    printf '%s\n' "${common_packages[@]}" \
      luci-app-ttyd \
      luci-app-store \
      quickstart \
      luci-app-quickstart
    ;;
  *)
    echo "unknown required-package variant: $variant" >&2
    exit 2
    ;;
esac
