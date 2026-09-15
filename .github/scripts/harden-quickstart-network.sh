#!/usr/bin/env bash
set -euo pipefail

package_dir="${1:?usage: $0 path/to/quickstart-package}"
init_file="$package_dir/files/startdhns.init"
hotplug_file="$package_dir/files/startdhns.hotplug"

python3 - "$init_file" "$hotplug_file" <<'PY'
from pathlib import Path
import sys

init_path = Path(sys.argv[1])
hotplug_path = Path(sys.argv[2])

unsafe_init = '''#!/bin/sh /etc/rc.common

START=93
USE_PROCD=1

start_service() {
\tlocal seconds
\tfor seconds in $(seq 0 2); do
\t\t/usr/sbin/quickstart uciChange | grep -q -e OK -e code:501 && break
\t\tsleep 1 && continue
\t\tbreak
\tdone
}

service_triggers()
{
\tprocd_add_reload_trigger network
}
'''

unsafe_hotplug = '''[ "$INTERFACE" = "planb" -o "$INTERFACE" = "wan" ] || exit 0

if [ "$ACTION" = "ifup" -o "$ACTION" = "ifupdate" ]; then
    /usr/sbin/quickstart ifaceEvent up "$INTERFACE"
fi

if [ "$ACTION" = "ifdown" ]; then
    /usr/sbin/quickstart ifaceEvent down "$INTERFACE"
fi
'''

safe_init = '''#!/bin/sh /etc/rc.common

# RE-SS-01 safety policy: keep the dashboard, but never let QuickStart rewrite
# the router network automatically during boot or a network reload.
START=93
USE_PROCD=1

start_service() {
\treturn 0
}
'''

safe_hotplug = '''#!/bin/sh

# RE-SS-01 safety policy: QuickStart must not react to WAN lifecycle events.
exit 0
'''

for path in (init_path, hotplug_path):
    if not path.is_file():
        raise SystemExit(f"QuickStart network hook is missing: {path}")

actual_init = init_path.read_text()
actual_hotplug = hotplug_path.read_text()

if actual_init == safe_init and actual_hotplug == safe_hotplug:
    raise SystemExit(0)
if actual_init != unsafe_init or actual_hotplug != unsafe_hotplug:
    raise SystemExit("QuickStart network hooks changed upstream; refusing an unverified patch")

init_path.write_text(safe_init)
hotplug_path.write_text(safe_hotplug)
PY
