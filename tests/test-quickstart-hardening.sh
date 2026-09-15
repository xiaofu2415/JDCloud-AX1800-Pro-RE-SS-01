#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hardener="$repo_root/.github/scripts/harden-quickstart-network.sh"
fixture="$repo_root/tests/fixtures/quickstart"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

package_dir="$temporary/quickstart"
mkdir -p "$package_dir/files"
cp "$fixture/startdhns.init" "$package_dir/files/startdhns.init"
cp "$fixture/startdhns.hotplug" "$package_dir/files/startdhns.hotplug"

[[ -x "$hardener" ]] || {
  echo "missing executable QuickStart network hardener" >&2
  exit 1
}

bash "$hardener" "$package_dir"

expected_init='#!/bin/sh /etc/rc.common

# RE-SS-01 safety policy: keep the dashboard, but never let QuickStart rewrite
# the router network automatically during boot or a network reload.
START=93
USE_PROCD=1

start_service() {
	return 0
}'
expected_hotplug='#!/bin/sh

# RE-SS-01 safety policy: QuickStart must not react to WAN lifecycle events.
exit 0'

[[ "$(cat "$package_dir/files/startdhns.init")" == "$expected_init" ]] || {
  echo "QuickStart boot/reload hook was not replaced with the safe no-op service" >&2
  exit 1
}
[[ "$(cat "$package_dir/files/startdhns.hotplug")" == "$expected_hotplug" ]] || {
  echo "QuickStart WAN hotplug hook was not replaced with the safe no-op hook" >&2
  exit 1
}

cp -R "$package_dir" "$temporary/hardened-once"
bash "$hardener" "$package_dir"
diff -ru "$temporary/hardened-once" "$package_dir"

unsafe_dir="$temporary/unknown-upstream"
mkdir -p "$unsafe_dir/files"
cp "$fixture/startdhns.init" "$unsafe_dir/files/startdhns.init"
cp "$fixture/startdhns.hotplug" "$unsafe_dir/files/startdhns.hotplug"
printf '\n# upstream changed\n' >> "$unsafe_dir/files/startdhns.init"
cp -R "$unsafe_dir" "$temporary/unknown-upstream-before"
if bash "$hardener" "$unsafe_dir" >/dev/null 2>&1; then
  echo "hardener must reject an unknown upstream QuickStart implementation" >&2
  exit 1
fi
diff -ru "$temporary/unknown-upstream-before" "$unsafe_dir"

echo "QuickStart automatic network mutation hardening: ok"
