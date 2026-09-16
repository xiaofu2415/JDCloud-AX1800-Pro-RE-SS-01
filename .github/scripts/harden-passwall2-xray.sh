#!/usr/bin/env bash
set -euo pipefail

feed_root="${1:?usage: harden-passwall2-xray.sh PASSWALL2_FEED_ROOT}"
utils_file="$feed_root/root/usr/share/passwall2/utils.sh"

[[ -f "$utils_file" ]] || {
  echo "PassWall2 utils.sh not found: $utils_file" >&2
  exit 1
}

# PassWall2 creates a runtime link in /tmp before every core launch.  The
# upstream implementation used plain `ln -s`, which leaves a stale link when
# the directory survives a restart.  Accept exactly the known upstream line;
# reject unrelated feed changes so a future source update cannot be patched
# silently.
old_pattern='^[[:space:]]*ln -s "\$\{file_func\}" "\$\{TMP_BIN_PATH\}/\$\{ln_name\}" >/dev/null 2>&1$'
new_pattern='^[[:space:]]*ln -sfn "\$\{file_func\}" "\$\{TMP_BIN_PATH\}/\$\{ln_name\}" >/dev/null 2>&1$'
mkdir_pattern='^[[:space:]]*mkdir -p "\$\{TMP_BIN_PATH\}"$'
old_count="$(grep -Ec "$old_pattern" "$utils_file" || true)"
new_count="$(grep -Ec "$new_pattern" "$utils_file" || true)"
mkdir_count="$(grep -Ec "$mkdir_pattern" "$utils_file" || true)"

if [[ "$old_count" == 0 && "$new_count" == 1 && "$mkdir_count" == 1 ]]; then
  exit 0
fi
[[ "$old_count" == 1 && "$new_count" == 0 && "$mkdir_count" == 0 ]] || {
  echo "unsupported PassWall2 utils.sh; refusing an unverified Xray hardening patch" >&2
  exit 1
}

temporary_file="$(mktemp "${utils_file}.XXXXXX")"
cleanup() {
  rm -f "$temporary_file"
}
trap cleanup EXIT HUP INT TERM

awk '
  /^[[:space:]]*ln -s "\$\{file_func\}" "\$\{TMP_BIN_PATH\}\/\$\{ln_name\}" >\/dev\/null 2>&1$/ {
    prefix = $0
    sub(/ln -s.*/, "", prefix)
    print prefix "mkdir -p \"${TMP_BIN_PATH}\""
    print prefix "ln -sfn \"${file_func}\" \"${TMP_BIN_PATH}/${ln_name}\" >/dev/null 2>&1"
    next
  }
  { print }
' "$utils_file" > "$temporary_file"
mode="$(stat -c '%a' "$utils_file" 2>/dev/null || stat -f '%Lp' "$utils_file")"
chmod "$mode" "$temporary_file"
mv "$temporary_file" "$utils_file"
trap - EXIT HUP INT TERM

grep -Eq "$new_pattern" "$utils_file"
