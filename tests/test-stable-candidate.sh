#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
defaults="$repo_root/files/etc/uci-defaults/99-re-ss-01-services"
fstab="$repo_root/files/etc/config/fstab"
version_file="$repo_root/versions/istore.version"
nlbw_fix="$repo_root/files/etc/init.d/re-ss-01-nlbwmon-fix"

[[ -f "$fstab" ]] || {
  echo "stable candidate must ship a device-scoped fstab policy" >&2
  exit 1
}

[[ -x "$nlbw_fix" ]] || {
  echo "stable candidate must ship an executable conntrack-netlink startup fix" >&2
  exit 1
}

grep -Fqx 'START=59' "$nlbw_fix"
grep -Fq 'rmmod nf_conntrack_netlink' "$nlbw_fix"
grep -Fq 'modprobe nf_conntrack_netlink' "$nlbw_fix"
grep -Fq '/etc/init.d/nlbwmon stop' "$nlbw_fix"
grep -Fq '/etc/init.d/nlbwmon start' "$nlbw_fix"
grep -Fq '/etc/init.d/re-ss-01-nlbwmon-fix enable' "$defaults"
grep -Fq '/etc/init.d/re-ss-01-nlbwmon-fix start' "$defaults"

grep -Fqx "uci -q set nlbwmon.@nlbwmon[0].commit_interval='5m'" "$defaults" || {
  echo "nlbwmon commit interval must be five minutes for observable stable statistics" >&2
  exit 1
}

grep -Fqx "0.1.0-rc.1" "$version_file" || {
  echo "iStore stable candidate must use version 0.1.0-rc.1" >&2
  exit 1
}

grep -Fqx "config mount" "$fstab"
grep -Fqx "config global autoswap" "$fstab"
grep -Fqx $'\toption anon_swap \'0\'' "$fstab"
grep -Fqx $'\toption auto_swap \'0\'' "$fstab"
grep -Fqx $'\toption target \'/mnt/storage\'' "$fstab"
grep -Fqx $'\toption uuid \'5d987db6-15b1-44db-9934-3bc086a4fd6e\'' "$fstab"
grep -Fqx $'\toption fstype \'ext4\'' "$fstab"
grep -Fqx $'\toption options \'rw,noatime\'' "$fstab"
grep -Fqx $'\toption enabled \'1\'' "$fstab"
grep -Fqx "config swap" "$fstab"
grep -Fqx $'\toption device \'/dev/mmcblk0p26\'' "$fstab"
grep -Fqx $'\toption priority \'10\'' "$fstab"

if rg -n -i '(^|[[:space:]])(mkfs|mkswap|dd[[:space:]])' "$repo_root/files"; then
  echo "stable candidate must never format or overwrite eMMC partitions" >&2
  exit 1
fi

grep -Fq '5 分钟' "$repo_root/README.md"
grep -Fq '5m' "$repo_root/docs/VARIANTS.md"

echo "stable candidate storage and nlbwmon contracts: ok"
