#!/usr/bin/env bash
set -euo pipefail

config_file="${1:?usage: harden-passwall2-shunt-defaults.sh PATH_TO_0_DEFAULT_CONFIG}"
test -f "$config_file"

front_count="$(grep -Fc "option DirectFront '_direct'" "$config_file" || true)"
game_count="$(grep -Fc "option DirectGame '_direct'" "$config_file" || true)"
marker_count="$(grep -Fc "option PrivateIP '_direct'" "$config_file" || true)"

if [[ "$front_count" == 1 && "$game_count" == 1 && "$marker_count" == 1 ]]; then
	exit 0
fi

[[ "$front_count" == 0 && "$game_count" == 0 && "$marker_count" == 1 ]] || {
	echo "unsupported PassWall2 default config; refusing an unverified shunt patch" >&2
	exit 1
}

python3 - "$config_file" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
source = path.read_text()
marker = "option PrivateIP '_direct'\n"
replacement = (
    marker
    + "option DirectFront '_direct'\n"
    + "option DirectGame '_direct'\n"
)
if source.count(marker) != 1:
    raise SystemExit("PassWall2 rulenode marker is not unique")
path.write_text(source.replace(marker, replacement, 1))
PY

grep -Fqx "option DirectFront '_direct'" "$config_file"
grep -Fqx "option DirectGame '_direct'" "$config_file"
