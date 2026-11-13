#!/usr/bin/env bash
set -euo pipefail

openwrt="$(cd "${1:?usage: collect-management-apks.sh OPENWRT OUTPUT}" && pwd)"
output="${2:?missing output directory}"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
for package in luci-app-tailscale-community fastnet luci-app-fastnet; do
  mapfile -t files < <(find "$openwrt/bin/packages" -type f -name "$package-[0-9]*.apk")
  if [[ ${#files[@]} != 1 ]]; then
    echo "Expected one $package APK; found ${#files[@]}" >&2
    exit 1
  fi
  cp "${files[0]}" "$output/"
done
cd "$output"
apk="$openwrt/staging_dir/host/bin/apk"
"$apk" mkndx --root "$openwrt" --keys-dir "$openwrt" --allow-untrusted \
  --sign "$openwrt/private-key.pem" --output packages.adb ./*.apk
cp "$openwrt/public-key.pem" ./re-ss-01-plugin-build.pem
sha256sum ./*.apk packages.adb re-ss-01-plugin-build.pem > SHA256SUMS
