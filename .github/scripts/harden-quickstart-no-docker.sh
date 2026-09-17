#!/usr/bin/env bash
set -euo pipefail

template="${1:?usage: harden-quickstart-no-docker.sh QUICKSTART_MAIN_TEMPLATE}"
[[ -f "$template" ]] || {
  echo "QuickStart main.htm not found: $template" >&2
  exit 1
}

expected_original_sha='806d968acb47afadc44f2bcb2c482f7149763a03f83934dc7323a9b95ae85fc2'
expected_patched_sha='8884c0eddd49ae97aff62f7831b98ac4f4030c41de40d6f60c092b9676d54ccc'
expected_status_sha='53c7c01eeacd13dd1483f69e5209bcf1f639dfe44235da6827649f2fcdf9750a'
expected_combined_sha='ba7da8d475caac9959c1e28e3c07bbb22d93133ef0e62784a0605d15fb4248de'
current_sha="$(sha256sum "$template" | awk '{print $1}')"
if [[ "$current_sha" == "$expected_patched_sha" || "$current_sha" == "$expected_combined_sha" ]]; then
  ! grep -Fq 'dockerd' "$template"
  exit 0
fi
[[ "$current_sha" == "$expected_original_sha" || "$current_sha" == "$expected_status_sha" ]] || {
  echo "unsupported QuickStart main.htm; refusing an unverified Docker removal" >&2
  exit 1
}

python3 - "$template" <<'PY'
from pathlib import Path
import os
import sys

path = Path(sys.argv[1])
source = path.read_text()
block = '''  if luci.sys.call("[ -e /etc/init.d/dockerd ] >/dev/null 2>&1") == 0 then
      features[#features+1] = "dockerd"
  end
'''

if source.count(block) == 0:
    if "dockerd" not in source:
        raise SystemExit(0)
    raise SystemExit("unsupported QuickStart Docker block; refusing an unverified removal")
if source.count(block) != 1:
    raise SystemExit("QuickStart Docker block is not unique")

patched = source.replace(block, "", 1)
if "dockerd" in patched:
    raise SystemExit("QuickStart still advertises Docker after the reviewed removal")

temporary = path.with_name(path.name + ".tmp")
temporary.write_text(patched)
temporary.chmod(path.stat().st_mode & 0o7777)
os.replace(temporary, path)
PY

patched_sha="$(sha256sum "$template" | awk '{print $1}')"
expected_output_sha="$expected_patched_sha"
if [[ "$current_sha" == "$expected_status_sha" ]]; then
  expected_output_sha="$expected_combined_sha"
fi
[[ "$patched_sha" == "$expected_output_sha" ]] || {
  echo "QuickStart Docker removal did not match the reviewed template" >&2
  exit 1
}
