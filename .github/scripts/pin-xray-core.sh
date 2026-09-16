#!/usr/bin/env bash
set -euo pipefail

makefile="${1:?usage: pin-xray-core.sh XRAY_CORE_MAKEFILE}"

python3 - "$makefile" <<'PY'
from pathlib import Path
import sys

makefile = Path(sys.argv[1])
if not makefile.is_file():
    raise SystemExit(f"xray-core Makefile not found: {makefile}")

source = makefile.read_text()
old = {
    "name": "PKG_NAME:=xray-core",
    "version": "PKG_VERSION:=26.3.27",
    "source_url": "PKG_SOURCE_URL:=https://codeload.github.com/XTLS/Xray-core/tar.gz/v$(PKG_VERSION)?",
    "hash": "PKG_HASH:=992a4997e6bb846d11469435d687f99ef812fcde1e0a009bb8e95189ea20331d",
    "go_dep": "PKG_BUILD_DEPENDS:=golang/host",
}
new = {
    "version": "PKG_VERSION:=26.9.9",
    "hash": "PKG_HASH:=efb871a981690688191433a76beef7afdab6750d53cc1775cf8e9e995730ef22",
}
for label in ("name", "source_url", "go_dep"):
    if source.count(old[label]) != 1:
        raise SystemExit(f"unexpected xray-core Makefile; expected one {label} line")

patch_path = makefile.parent / "patches" / "100-go-1.26-compat.patch"
patch = """--- a/go.mod
+++ b/go.mod
@@ -1,4 +1,4 @@
 module github.com/xtls/xray-core
 
-go 1.27
+go 1.26
"""

if source.count(new["version"]) == 1 and source.count(new["hash"]) == 1:
    if patch_path.is_file() and patch_path.read_text() == patch:
        raise SystemExit(0)
    raise SystemExit("xray-core is already upgraded but its Go compatibility patch is missing or changed")

if any(source.count(line) for line in new.values()):
    raise SystemExit("xray-core Makefile contains a partial unverified upgrade")

for label in ("version", "hash"):
    if source.count(old[label]) != 1:
        raise SystemExit(f"unexpected xray-core Makefile; expected one old {label} line")

for old_line, new_line in ((old["version"], new["version"]), (old["hash"], new["hash"])):
    source = source.replace(old_line, new_line, 1)
makefile.write_text(source)

if patch_path.exists() and patch_path.read_text() != patch:
    raise SystemExit("existing Xray Go compatibility patch is not the verified patch")
patch_path.parent.mkdir(parents=True, exist_ok=True)
patch_path.write_text(patch)
PY
