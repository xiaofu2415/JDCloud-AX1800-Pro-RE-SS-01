#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

require_file() {
  local path="$1"
  [[ -f "$path" ]] || {
    echo "missing remediation file: ${path#"$repo_root/"}" >&2
    exit 1
  }
}

require_executable() {
  local path="$1"
  require_file "$path"
  [[ -x "$path" ]] || {
    echo "remediation helper is not executable: ${path#"$repo_root/"}" >&2
    exit 1
  }
}

require_text() {
  local path="$1"
  local expected="$2"
  grep -Fqx "$expected" "$path" || {
    echo "${path#"$repo_root/"} is missing required contract: $expected" >&2
    exit 1
  }
}

require_match() {
  local path="$1"
  local pattern="$2"
  grep -Eq "$pattern" "$path" || {
    echo "${path#"$repo_root/"} is missing required pattern: $pattern" >&2
    exit 1
  }
}

normalize="$repo_root/files/usr/libexec/re-ss-01-normalize-apk-feeds"
passwall_hardener="$repo_root/.github/scripts/harden-passwall2-xray.sh"
quickstart_ui_hardener="$repo_root/.github/scripts/harden-quickstart-status-ui.sh"
samba_acl_verifier="$repo_root/.github/scripts/verify-samba4-acl.sh"
feed_defaults="$repo_root/files/etc/uci-defaults/98-re-ss-01-apk-feeds"
service_defaults="$repo_root/files/etc/uci-defaults/99-re-ss-01-services"
ttyd_rebind="$repo_root/files/etc/hotplug.d/iface/95-ttyd-lan-rebind"
workflow="$repo_root/.github/workflows/build-re-ss-01.yml"
config="$repo_root/configs/re-ss-01-istore.config"
required_packages="$repo_root/.github/scripts/required-packages.sh"

require_executable "$normalize"
require_executable "$passwall_hardener"
require_executable "$quickstart_ui_hardener"
require_executable "$samba_acl_verifier"
require_file "$feed_defaults"
require_file "$ttyd_rebind"

require_match "$feed_defaults" '/usr/libexec/re-ss-01-normalize-apk-feeds'
require_text "$service_defaults" "uci -q set sqm.@queue[0].interface='wan'"
require_text "$service_defaults" "uci -q set sqm.@queue[0].enabled='0'"
require_match "$service_defaults" 'for service .*samba4|/etc/init\.d/samba4 disable'
require_match "$ttyd_rebind" 'INTERFACE.*lan|\[.*lan.*\]'
require_match "$ttyd_rebind" 'ttyd_init.*restart|/etc/init\.d/ttyd.*restart'
require_text "$config" 'CONFIG_PACKAGE_luci-app-samba4=y'
require_text "$config" 'CONFIG_PACKAGE_samba4-server=y'
require_text "$config" 'CONFIG_PACKAGE_block-mount=y'
require_match "$workflow" 'bash \.github/scripts/harden-passwall2-xray\.sh openwrt/feeds/passwall2/luci-app-passwall2'
require_match "$workflow" 'bash \.github/scripts/harden-quickstart-status-ui\.sh openwrt/feeds/nas_luci/luci/luci-app-quickstart'
require_match "$workflow" 'bash \.github/scripts/verify-samba4-acl\.sh openwrt/feeds/luci/applications/luci-app-samba4'
require_text "$repo_root/versions/istore.version" '0.1.0-beta.3'

packages="$($required_packages istore)"
for package in luci-app-samba4 samba4-server block-mount; do
  grep -Fxq "$package" <<< "$packages" || {
    echo "iStore package policy is missing: $package" >&2
    exit 1
  }
done

temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
mkdir -p "$temporary/etc/apk/repositories.d"
feed_file="$temporary/etc/apk/repositories.d/custom.list"
printf '%s\n' \
  '# keep comments and order' \
  'https://mirrors.vsean.net/openwrt/releases/25.12.2/packages/aarch64_cortex-a53/istore/packages.adb' \
  'https://downloads.openwrt.org/releases/25.12.2/targets/qualcommax/ipq60xx/packages.adb' \
  'https://mirrors.vsean.net/openwrt/releases/25.12.2/packages/aarch64_cortex-a53/passwall2/packages.adb' \
  'https://istore.istoreos.com/repo-apk/all/compat/packages.adb' \
  'https://mirrors.vsean.net/openwrt/releases/25.12.2/packages/aarch64_cortex-a53/video/packages.adb' \
  > "$feed_file"
cp "$feed_file" "$temporary/before.list"
"$normalize" "$temporary"
grep -Fqx '# keep comments and order' "$feed_file"
grep -Fqx 'https://downloads.openwrt.org/releases/25.12.2/targets/qualcommax/ipq60xx/packages.adb' "$feed_file"
grep -Fqx 'https://istore.istoreos.com/repo-apk/all/compat/packages.adb' "$feed_file"
if grep -Eq '/(istore|passwall2|video)/packages\.adb' "$feed_file"; then
  echo "invalid runtime APK feed was not removed" >&2
  exit 1
fi
cp "$feed_file" "$temporary/after-once.list"
"$normalize" "$temporary"
diff -u "$temporary/after-once.list" "$feed_file"

passwall_feed="$temporary/passwall"
mkdir -p "$passwall_feed/root/usr/share/passwall2"
passwall_utils="$passwall_feed/root/usr/share/passwall2/utils.sh"
printf '%s\n' \
  'TMP_BIN_PATH=/tmp/etc/passwall2/bin' \
  'ln_run() {' \
  '  file_func="$1"' \
  '  ln -s "${file_func}" "${TMP_BIN_PATH}/${ln_name}" >/dev/null 2>&1' \
  '}' \
  > "$passwall_utils"
cp "$passwall_utils" "$temporary/passwall-before.list"
"$passwall_hardener" "$passwall_feed"
grep -Fqx '  mkdir -p "${TMP_BIN_PATH}"' "$passwall_utils"
grep -Fqx '  ln -sfn "${file_func}" "${TMP_BIN_PATH}/${ln_name}" >/dev/null 2>&1' "$passwall_utils"
cp "$passwall_utils" "$temporary/passwall-after-once.list"
"$passwall_hardener" "$passwall_feed"
diff -u "$temporary/passwall-after-once.list" "$passwall_utils"

unknown_passwall="$temporary/unknown-passwall"
mkdir -p "$unknown_passwall/root/usr/share/passwall2"
printf '%s\n' \
  'TMP_BIN_PATH=/tmp/etc/passwall2/bin' \
  'ln_run() {' \
  '  file_func="$1"' \
  '  ln -s "${file_func}" "${TMP_BIN_PATH}/${ln_name}"' \
  '}' \
  > "$unknown_passwall/root/usr/share/passwall2/utils.sh"
cp "$unknown_passwall/root/usr/share/passwall2/utils.sh" "$temporary/unknown-passwall-before.list"
if "$passwall_hardener" "$unknown_passwall" >/dev/null 2>&1; then
  echo "PassWall2 hardener must reject an unknown upstream utils.sh" >&2
  exit 1
fi
diff -u "$temporary/unknown-passwall-before.list" "$unknown_passwall/root/usr/share/passwall2/utils.sh"

ttyd_root="$temporary/ttyd-root"
mkdir -p "$ttyd_root/etc/init.d" "$ttyd_root/tmp"
ttyd_calls="$ttyd_root/tmp/ttyd-calls"
cat > "$ttyd_root/etc/init.d/ttyd" <<EOF
#!/bin/sh
case "\$1" in
  enabled|running) exit 0 ;;
  restart) printf '%s\\n' restart >> "$ttyd_calls" ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$ttyd_root/etc/init.d/ttyd"
TTYD_REBIND_ROOT="$ttyd_root" ACTION=ifup INTERFACE=lan "$ttyd_rebind"
[[ "$(wc -l < "$ttyd_calls")" -eq 1 ]]
TTYD_REBIND_ROOT="$ttyd_root" ACTION=ifupdate INTERFACE=lan "$ttyd_rebind"
[[ "$(wc -l < "$ttyd_calls")" -eq 1 ]]
TTYD_REBIND_ROOT="$ttyd_root" ACTION=ifup INTERFACE=wan "$ttyd_rebind"
TTYD_REBIND_ROOT="$ttyd_root" ACTION=ifdown INTERFACE=lan "$ttyd_rebind"
[[ "$(wc -l < "$ttyd_calls")" -eq 1 ]]
if grep -Eq '0\.0\.0\.0|firewall|INTERFACE=wan|[[:space:]]wan[[:space:]]' "$ttyd_rebind"; then
  echo "ttyd LAN rebind helper must not add WAN exposure" >&2
  exit 1
fi

quickstart_feed="$temporary/quickstart-ui"
mkdir -p "$quickstart_feed/luasrc/view/quickstart"
quickstart_template="$quickstart_feed/luasrc/view/quickstart/main.htm"
cp "$repo_root/tests/fixtures/quickstart/main.htm" "$quickstart_template"
cp "$quickstart_template" "$temporary/quickstart-before.htm"
"$quickstart_ui_hardener" "$quickstart_feed"
grep -Fq 'RE-SS-01 兼容提示' "$quickstart_template"
grep -Fq '/cgi-bin/luci/admin/status/overview' "$quickstart_template"
grep -Fq '/cgi-bin/luci/admin/system/mounts' "$quickstart_template"
notice_block="$(grep -A2 -B0 'RE-SS-01 兼容提示' "$quickstart_template")"
if grep -Eq 'https?://|<script' <<< "$notice_block"; then
  echo "QuickStart compatibility notice must not add external scripts" >&2
  exit 1
fi
cp "$quickstart_template" "$temporary/quickstart-after-once.htm"
"$quickstart_ui_hardener" "$quickstart_feed"
diff -u "$temporary/quickstart-after-once.htm" "$quickstart_template"

unknown_quickstart="$temporary/unknown-quickstart"
mkdir -p "$unknown_quickstart/luasrc/view/quickstart"
cp "$repo_root/tests/fixtures/quickstart/main.htm" "$unknown_quickstart/luasrc/view/quickstart/main.htm"
printf '%s\n' '<!-- upstream changed -->' >> "$unknown_quickstart/luasrc/view/quickstart/main.htm"
cp "$unknown_quickstart/luasrc/view/quickstart/main.htm" "$temporary/unknown-quickstart-before.htm"
if "$quickstart_ui_hardener" "$unknown_quickstart" >/dev/null 2>&1; then
  echo "QuickStart UI hardener must reject an unknown upstream template" >&2
  exit 1
fi
diff -u "$temporary/unknown-quickstart-before.htm" "$unknown_quickstart/luasrc/view/quickstart/main.htm"

samba_feed="$temporary/samba4"
mkdir -p "$samba_feed/root/usr/share/rpcd/acl.d"
samba_acl="$samba_feed/root/usr/share/rpcd/acl.d/luci-app-samba4.json"
cp "$repo_root/tests/fixtures/samba4/luci-app-samba4.json" "$samba_acl"
"$samba_acl_verifier" "$samba_feed"

vulnerable_samba="$temporary/vulnerable-samba4"
mkdir -p "$vulnerable_samba/root/usr/share/rpcd/acl.d"
sed 's#smbd -V#smbd#' "$repo_root/tests/fixtures/samba4/luci-app-samba4.json" > "$vulnerable_samba/root/usr/share/rpcd/acl.d/luci-app-samba4.json"
cp "$vulnerable_samba/root/usr/share/rpcd/acl.d/luci-app-samba4.json" "$temporary/vulnerable-samba4-before.json"
if "$samba_acl_verifier" "$vulnerable_samba" >/dev/null 2>&1; then
  echo "Samba4 ACL verifier must reject the vulnerable smbd exec ACL" >&2
  exit 1
fi
diff -u "$temporary/vulnerable-samba4-before.json" "$vulnerable_samba/root/usr/share/rpcd/acl.d/luci-app-samba4.json"

echo "iStore beta.3 remediation contracts: ok"
