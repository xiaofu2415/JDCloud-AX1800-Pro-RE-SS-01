#!/usr/bin/env bash
set -euo pipefail

image_makefile="${1:?usage: $0 path/to/ipq60xx.mk}"
test -f "$image_makefile"

python3 - "$image_makefile" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
source = path.read_text()
pattern = re.compile(r"^define Device/jdcloud_re-ss-01\n.*?^endef$", re.MULTILINE | re.DOTALL)
match = pattern.search(source)
if match is None:
    raise SystemExit("RE-SS-01 device definition not found")

old = "IMAGE/factory.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-rootfs | append-metadata"
new = "IMAGE/factory.bin := append-kernel | pad-to $$(KERNEL_SIZE) | append-rootfs | pad-rootfs | pad-to 64k"
device = match.group(0)
if device.count(old) != 1:
    raise SystemExit("unexpected RE-SS-01 factory image definition")

patched = device.replace(old, new, 1)
path.write_text(source[:match.start()] + patched + source[match.end():])
PY
