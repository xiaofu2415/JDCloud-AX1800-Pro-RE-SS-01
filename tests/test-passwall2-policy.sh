#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
defaults="$repo_root/files/etc/uci-defaults/99-re-ss-01-services"
sync="$repo_root/files/usr/libexec/re-ss-01-passwall2-sync"
init="$repo_root/files/etc/init.d/re-ss-01-passwall2-sync"
hardener="$repo_root/.github/scripts/harden-passwall2-shunt-defaults.sh"

for path in "$defaults" "$sync" "$init" "$hardener"; do
  [[ -f "$path" ]] || { echo "missing PassWall2 policy file: ${path#"$repo_root/"}" >&2; exit 1; }
done
[[ -x "$sync" ]] || { echo "PassWall2 sync helper must be executable" >&2; exit 1; }
[[ -x "$init" ]] || { echo "PassWall2 policy init script must be executable" >&2; exit 1; }
[[ -x "$hardener" ]] || { echo "PassWall2 shunt hardener must be executable" >&2; exit 1; }

grep -Fq 'START=98' "$init" || {
  echo "PassWall2 policy sync must run before the stock START=99 service" >&2
  exit 1
}
grep -Fq 'default_node' "$sync" || {
  echo "PassWall2 policy sync must repair the placeholder default node" >&2
  exit 1
}
grep -Fq 'pidof xray' "$sync" || {
  echo "PassWall2 policy sync must verify the real Xray process" >&2
  exit 1
}

grep -Fq 'passwall2.rulenode.$rule='\''_direct'\''' "$defaults" || {
  echo "first boot must persist the DirectFront direct mapping" >&2
  exit 1
}
grep -Fq "/usr/libexec/re-ss-01-passwall2-sync sync" "$defaults" || {
  echo "first boot must invoke the PassWall2 policy sync" >&2
  exit 1
}
grep -Fq 'for service in passwall2' "$defaults" || {
  echo "PassWall2 must remain disabled when the global switch is off" >&2
  exit 1
}

fixture_config="$(mktemp)"
trap 'rm -rf "$fixture" "$fixture_config" "${fixture_config}.once"' EXIT
printf '%s\n' \
  "config nodes 'rulenode'" \
  "option PrivateIP '_direct'" \
  "option default_node 'examplenode'" \
  "option shunt_group 'CN'" \
  > "$fixture_config"
"$hardener" "$fixture_config"
grep -Fxq "option DirectFront '_direct'" "$fixture_config"
grep -Fxq "option DirectGame '_direct'" "$fixture_config"
cp "$fixture_config" "$fixture_config.once"
"$hardener" "$fixture_config"
diff -u "$fixture_config.once" "$fixture_config"

fixture="$(mktemp -d)"
mkdir -p "$fixture/bin" "$fixture/etc/init.d" "$fixture/state"
printf '0\n' > "$fixture/state/enabled"
printf '0\n' > "$fixture/state/directfront"
printf '0\n' > "$fixture/state/directgame"
printf '0\n' > "$fixture/state/rulenode"
printf '0\n' > "$fixture/state/rule"
printf '0\n' > "$fixture/state/running"
printf 'examplenode\n' > "$fixture/state/default_node"
printf '%s\n' examplenode 08iyICrG > "$fixture/state/nodes"
: > "$fixture/state/uci-calls"
: > "$fixture/state/service-calls"

cat > "$fixture/bin/uci" <<'EOF'
#!/bin/sh
state_dir="${FAKE_STATE_DIR:?}"
while [ "$#" -gt 0 ] && [ "$1" = "-q" ]; do shift; done
command="${1:-}"
shift || true
case "$command" in
  get)
    key="${1:-}"
    case "$key" in
      passwall2.@global\[0\].enabled) cat "$state_dir/enabled"; exit 0 ;;
      passwall2.rulenode) [ "$(cat "$state_dir/rulenode")" = 1 ] || exit 1; echo rulenode; exit 0 ;;
      passwall2.rulenode.default_node) cat "$state_dir/default_node"; exit 0 ;;
      passwall2.rulenode.DirectFront) [ "$(cat "$state_dir/directfront")" = 1 ] || exit 1; echo _direct; exit 0 ;;
      passwall2.DirectFront.remarks) [ "$(cat "$state_dir/rule")" = 1 ] || exit 1; echo DirectFront; exit 0 ;;
      passwall2.rulenode.DirectGame) [ "$(cat "$state_dir/directgame")" = 1 ] || exit 1; echo _direct; exit 0 ;;
      passwall2.DirectGame.remarks) [ "$(cat "$state_dir/rule")" = 1 ] || exit 1; echo DirectGame; exit 0 ;;
    esac
    exit 1
    ;;
  show)
    [ "${1:-}" = passwall2 ] || exit 1
    printf '%s\n' 'passwall2.examplenode=nodes' 'passwall2.rulenode=nodes'
    while IFS= read -r node; do
      [ -n "$node" ] || continue
      [ "$node" = examplenode ] && continue
      printf 'passwall2.%s=nodes\n' "$node"
    done < "$state_dir/nodes"
    exit 0
    ;;
  set)
    assignment="${1:-}"
    printf '%s\n' "$assignment" >> "$state_dir/uci-calls"
    case "$assignment" in
      passwall2.rulenode.default_node=*)
        value="${assignment#*=}"
        value="${value#\'}"
        value="${value%\'}"
        printf '%s\n' "$value" > "$state_dir/default_node"
        ;;
      passwall2.rulenode.DirectFront=*) printf '1\n' > "$state_dir/directfront" ;;
      passwall2.rulenode.DirectGame=*) printf '1\n' > "$state_dir/directgame" ;;
    esac
    exit 0
    ;;
  commit) printf 'commit %s\n' "${1:-}" >> "$state_dir/uci-calls"; exit 0 ;;
esac
exit 1
EOF
chmod +x "$fixture/bin/uci"

cat > "$fixture/etc/init.d/passwall2" <<'EOF'
#!/bin/sh
state_dir="${FAKE_STATE_DIR:?}"
printf '%s\n' "${1:-}" >> "$state_dir/service-calls"
case "${1:-}" in
  enable|disable) exit 0 ;;
  status) [ "$(cat "$state_dir/running")" = 1 ] ;;
  start) printf '1\n' > "$state_dir/running"; printf 'ready\n' > "$state_dir/acl_default.json"; exit 0 ;;
esac
exit 1
EOF
chmod +x "$fixture/etc/init.d/passwall2"

cat > "$fixture/bin/pidof" <<'EOF'
#!/bin/sh
state_dir="${FAKE_STATE_DIR:?}"
[ "${1:-}" = xray ] || exit 1
[ "$(cat "$state_dir/running")" = 1 ] || exit 1
echo 2001
EOF
chmod +x "$fixture/bin/pidof"

run_sync() {
  FAKE_STATE_DIR="$fixture/state" \
    RE_SS_01_UCI="$fixture/bin/uci" \
    RE_SS_01_INIT_DIR="$fixture/etc/init.d" \
    RE_SS_01_ACL_PATH="$fixture/state/acl_default.json" \
    PATH="$fixture/bin:$PATH" \
    "$sync" sync
}

# A fresh image has the stock DirectFront rule and rulenode section. The
# global switch remains off, but init stays enabled so a later LuCI toggle can
# start PassWall2 without a second manual change in the startup page.
printf '1\n' > "$fixture/state/rulenode"
printf '1\n' > "$fixture/state/rule"
run_sync
grep -Fxq "passwall2.rulenode.DirectFront='_direct'" "$fixture/state/uci-calls"
grep -Fxq "passwall2.rulenode.DirectGame='_direct'" "$fixture/state/uci-calls"
grep -Fxq "passwall2.rulenode.default_node='08iyICrG'" "$fixture/state/uci-calls"
grep -Fxq 'commit passwall2' "$fixture/state/uci-calls"
grep -Fxq 'enable' "$fixture/state/service-calls"
! grep -Fxq 'disable' "$fixture/state/service-calls"
! grep -Fxq 'start' "$fixture/state/service-calls"

# Once the user enables the global switch, the policy must make the init
# state and runtime state agree. A second sync must not start it twice.
printf '1\n' > "$fixture/state/enabled"
: > "$fixture/state/service-calls"
run_sync
grep -Fxq 'enable' "$fixture/state/service-calls"
grep -Fxq 'start' "$fixture/state/service-calls"
: > "$fixture/state/service-calls"
run_sync
! grep -Fxq 'start' "$fixture/state/service-calls"

# An explicitly selected real node must not be replaced.
printf '08iyICrG\n' > "$fixture/state/default_node"
: > "$fixture/state/uci-calls"
run_sync
! grep -Fq 'passwall2.rulenode.default_node=' "$fixture/state/uci-calls"

# Multiple real nodes are ambiguous; leave the placeholder for an explicit
# user choice and emit a warning rather than guessing.
printf '%s\n' examplenode 08iyICrG secondnode > "$fixture/state/nodes"
printf 'examplenode\n' > "$fixture/state/default_node"
: > "$fixture/state/uci-calls"
: > "$fixture/state/service-calls"
run_sync
! grep -Fq 'passwall2.rulenode.default_node=' "$fixture/state/uci-calls"

echo "PassWall2 policy contracts: ok"
