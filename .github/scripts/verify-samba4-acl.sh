#!/usr/bin/env bash
set -euo pipefail

package_root="${1:?usage: verify-samba4-acl.sh SAMBA4_PACKAGE_ROOT}"
acl_file="$package_root/root/usr/share/rpcd/acl.d/luci-app-samba4.json"

[[ -f "$acl_file" ]] || {
  echo "Samba4 LuCI ACL not found: $acl_file" >&2
  exit 1
}

python3 -m json.tool "$acl_file" >/dev/null
if grep -Eq '"/usr/sbin/smbd"[[:space:]]*:[[:space:]]*\[[[:space:]]*"exec"' "$acl_file"; then
  echo "vulnerable Samba4 ACL grants exec to /usr/sbin/smbd" >&2
  exit 1
fi

fixed_count="$(grep -Ec '"/usr/sbin/smbd -V"[[:space:]]*:[[:space:]]*\[[[:space:]]*"exec"' "$acl_file" || true)"
[[ "$fixed_count" == 1 ]] || {
  echo "unsupported Samba4 ACL; expected exactly one /usr/sbin/smbd -V exec entry" >&2
  exit 1
}

exit 0
