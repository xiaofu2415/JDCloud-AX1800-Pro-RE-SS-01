#!/usr/bin/env bash
set -euo pipefail

packages_feed="${1:?usage: verify-xray-core.sh PACKAGES_FEED}"
xray_makefile="$packages_feed/net/xray-core/Makefile"
go_makefile="$packages_feed/lang/golang/golang1.27/Makefile"

require_line() {
  local path="$1" line="$2"
  if [[ ! -f "$path" ]] || [[ "$(grep -Fxc -- "$line" "$path" || true)" != 1 ]]; then
    printf 'Expected exactly one %s in %s\n' "$line" "$path" >&2
    exit 1
  fi
}

require_line "$xray_makefile" 'PKG_NAME:=xray-core'
require_line "$xray_makefile" 'PKG_VERSION:=26.10.21'
require_line "$xray_makefile" 'PKG_SOURCE_URL:=https://codeload.github.com/XTLS/Xray-core/tar.gz/v$(PKG_VERSION)?'
require_line "$xray_makefile" 'PKG_HASH:=44ef4874529a03848c90f1fdcfb763350fbc5f1de741ec90e0024d651df25650'
require_line "$xray_makefile" 'PKG_BUILD_DEPENDS:=golang1.27/host'
require_line "$go_makefile" 'PKG_NAME:=golang1.27'
require_line "$go_makefile" 'GO_VERSION_MAJOR_MINOR:=1.27'
