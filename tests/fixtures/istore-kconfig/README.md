# iStore selection regression

This reduced Kconfig fixture captures the transitive constraint that caused
GitHub run #5 to drop `luci-app-store` after `make defconfig`:

`luci-app-store` selects `tar`; tar enables `PACKAGE_TAR_XZ` by default and
selects `xz`; xz has a non-selecting dependency on `xz-utils`. LibWrt's metadata
generator propagates that dependency back to tar and iStore.

Sources inspected for this fixture:

- [iStore Makefile at 3fca15b](https://github.com/linkease/istore/blob/3fca15b30aeed9ecacb3efc8b4a8b9c2584ad5c7/luci/luci-app-store/Makefile)
- [tar at 06325d9](https://github.com/immortalwrt/packages/blob/06325d98456698cd450980625faeed292426c8c0/utils/tar/Makefile)
- [xz at 06325d9](https://github.com/immortalwrt/packages/blob/06325d98456698cd450980625faeed292426c8c0/utils/xz/Makefile)
- [LibWrt metadata generator at afe4162](https://github.com/LiBwrt/LibWrt/blob/afe416250dce05e20811192f01d3d387d99e8888/scripts/package-metadata.pl)

Only this dependency chain is retained. Other iStore dependencies, target
selection, firmware compilation and runtime behavior are outside the fixture's
scope. The test runs the actual LibWrt Kconfig parser on the builder's actual
iStore config, then runs a negative control with `xz-utils` disabled. It does
not emulate Kconfig or claim that a reduced fixture is a full firmware build.

Build the parser in a separate LibWrt checkout and run from the builder repo:

```sh
make -C /absolute/path/to/LibWrt/scripts/config conf
bash tests/test-istore-kconfig.sh /absolute/path/to/LibWrt/scripts/config/conf
```
