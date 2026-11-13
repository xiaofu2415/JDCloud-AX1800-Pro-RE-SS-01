#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
policy="$repo_root/files/etc/uci-defaults/11-re-ss-01-tailscale-autostart"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

check_policy() (
  local name="$1" initial="$2" restored="$3" expected="$4"
  local root="$temporary/$name"
  export IPKG_INSTROOT="$root"
  mkdir -p "$root/etc/init.d" "$root/etc/uci-defaults"
  printf '%s\n' "$initial" > "$root/autostart"
  cat > "$root/etc/init.d/tailscale" <<'EOF'
#!/bin/sh
[ "$#" -eq 1 ] && [ "$1" = disable ] || exit 1
printf '%s\n' disabled > "$IPKG_INSTROOT/autostart"
printf '%s\n' disable >> "$IPKG_INSTROOT/actions"
EOF
  chmod +x "$root/etc/init.d/tailscale"

  # sysupgrade always emits the restore script; only disabled services get
  # an action. Image assembly starts with the Tailscale init link enabled.
  case "$restored" in
    none) ;;
    enabled) printf '%s\n' 'exit 0' > "$root/etc/uci-defaults/10_disable_services" ;;
    disabled) printf '%s\n' '"$IPKG_INSTROOT/etc/init.d/tailscale" disable' 'exit 0' > "$root/etc/uci-defaults/10_disable_services" ;;
  esac
  cp "$policy" "$root/etc/uci-defaults/${policy##*/}"
  local file
  for file in "$root"/etc/uci-defaults/*; do
    ( . "$file" )
  done
  [[ "$(cat "$root/autostart")" == "$expected" ]]
  case "$restored" in
    enabled) [[ ! -e "$root/actions" ]] ;;
    *) [[ "$(cat "$root/actions")" == disable ]] ;;
  esac
)

check_policy fresh-image enabled none disabled
check_policy retain-enabled enabled enabled enabled
check_policy retain-disabled enabled disabled disabled
echo "Tailscale autostart defaults and sysupgrade restore: ok"
