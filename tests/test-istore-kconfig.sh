#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
conf="${1:?usage: test-istore-kconfig.sh /absolute/path/to/LibWrt/scripts/config/conf}"
[[ "$conf" = /* && -x "$conf" ]] || { echo "provide an executable absolute Kconfig conf path" >&2; exit 2; }
fixture="$repo_root/tests/fixtures/istore-kconfig/Config.in"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

cp "$repo_root/configs/re-ss-01-istore.config" "$temporary/input.config"
KCONFIG_CONFIG="$temporary/resolved.config" "$conf" \
  --defconfig="$temporary/input.config" "$fixture" > "$temporary/resolve.log" 2>&1
for package in luci-app-store tar xz xz-utils; do
  grep -qx "CONFIG_PACKAGE_${package}=y" "$temporary/resolved.config" || {
    echo "iStore defconfig regression: ${package} was dropped by the tar/xz dependency chain" >&2
    exit 1
  }
done
grep -qx 'CONFIG_PACKAGE_TAR_XZ=y' "$temporary/resolved.config"

# Negative control reproduces the cloud condition and proves fixture sensitivity.
sed '/^CONFIG_PACKAGE_xz-utils=/d' "$temporary/input.config" > "$temporary/missing-parent.config"
printf '%s\n' '# CONFIG_PACKAGE_xz-utils is not set' >> "$temporary/missing-parent.config"
KCONFIG_CONFIG="$temporary/negative.config" "$conf" \
  --defconfig="$temporary/missing-parent.config" "$fixture" > "$temporary/negative.log" 2>&1
if grep -qx 'CONFIG_PACKAGE_luci-app-store=y' "$temporary/negative.config"; then
  echo "iStore Kconfig negative control did not reproduce the missing package" >&2
  exit 1
fi
echo "iStore tar/xz Kconfig regression and negative control: ok"
