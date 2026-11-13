#!/usr/bin/env bash
set -euo pipefail

openwrt="${1:?usage: prepare-management-plugins.sh OPENWRT}"
builder="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tailscale="$openwrt/feeds/luci/applications/luci-app-tailscale-community"
fastnet="$openwrt/feeds/nas/network/services/fastnet"
fastnet_ui="$openwrt/feeds/nas_luci/luci/luci-app-fastnet"

# This exact rpcd backend matches the fixed OpenWrt 25.12 source.
test "$(git hash-object "$tailscale/root/usr/share/rpcd/ucode/tailscale.uc")" = 2a30bdbfbadc285133c25b3d50dd6ae4b5317bf4
grep -Fq '"admin/services/tailscale"' "$tailscale/root/usr/share/luci/menu.d/luci-app-tailscale-community.json"

# Replace the reviewed upstream first-boot script, which otherwise opens
# TCP 3200 on WAN and starts FastNet. Keep existing host, port and token.
test "$(git hash-object "$fastnet/files/fastnet.uci-default")" = f1b8b4271d0dd25641d2d89f5601ba178e45b055
python3 - "$fastnet/files/fastnet.config" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = "option enabled '1'"
if source.count(old) != 1:
    raise SystemExit("Unexpected FastNet enabled default")
path.write_text(source.replace(old, "option enabled '0'", 1))
PY
grep -Eq "^[[:space:]]*option enabled '0'$" "$fastnet/files/fastnet.config"
install -m 0755 "$builder/files/etc/uci-defaults/96-re-ss-01-fastnet" "$fastnet/files/fastnet.uci-default"
# Escape the legacy UI link before embedding it in the HTML attribute.
view="$fastnet_ui/luasrc/view/fastnet/status.htm"
test "$(git hash-object "$view")" = e3eb20e263fcb26ce45ab8eae0e5771278d4d579
python3 - "$view" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
path.write_text(source.replace("<%=self.url%>", '<%=require("luci.util").pcdata(self.url)%>', 1))
PY
grep -Fq 'require("luci.util").pcdata(self.url)' "$view"
