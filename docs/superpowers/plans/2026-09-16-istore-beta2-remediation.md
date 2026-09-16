# iStoreOS Dashboard beta.3 Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 发布 `re-ss-01-istore-v0.1.0-beta.3`，修复 beta.2 的软件源、PassWall2 启动目录竞态、Samba、ttyd、SQM 和 QuickStart 状态展示问题，同时保持 RE-SS-01 网络安全边界。

**Architecture:** 继续以 `LiBwrt/LibWrt:25.12-nss` 为固件基座，所有兼容修复都放在构建仓库的可测试脚本或 rootfs overlay 中，不直接维护完整上游源码分叉。对闭源 QuickStart 后端不做二进制修改；无法可靠修正的数据由 LuCI 兼容提示替代，并以标准 LuCI 页面作为权威入口。

**Tech Stack:** GitHub Actions、LibWrt/OpenWrt buildroot、APK、POSIX shell、LuCI Lua 模板、shunit 风格 shell 回归测试、RE-SS-01 真机验收。

**Spec:** `docs/superpowers/specs/2026-09-05-dual-firmware-release-design.md`

## Global Constraints

- 目标只能是 `qualcommax/ipq60xx/jdcloud_re-ss-01`。
- iStore 变体保持 prerelease，不得覆盖现有 beta.2 Release，不得成为 GitHub Latest。
- LAN 默认地址不得在未获得用户选择时自动改写；sysupgrade 保留用户当前配置。
- PassWall2、MosDNS、AdGuard Home、Docker、Tailscale、Samba 和 SQM 默认关闭；nlbwmon 默认启用并保留 3 期数据库。
- ttyd 只允许 LAN 侧访问，不新增 WAN accept 规则。
- 不自动格式化或覆盖任何 eMMC 分区，不自动启用 swap。
- 每个修复先有失败测试，再实现最小改动；云编译成功不等于真机验收通过。

---

### Task 1: 固定 beta.2 问题基线与回归入口

**Files:**
- Modify: `docs/KNOWN-ISSUES-ISTORE-BETA2.md`
- Create: `tests/test-istore-remediation.sh`
- Modify: `tests/test-builder.sh`

**Interfaces:**
- Consumes: beta.2 真机日志、LuCI 路由、APK 更新输出和发布 manifest。
- Produces: 单一入口 `bash tests/test-istore-remediation.sh`，供后续任务逐项增加断言。

- [ ] **Step 1: 写入失败测试**

在 `tests/test-istore-remediation.sh` 中断言以下文件或配置必须存在：运行时软件源清理脚本、Samba 包选择、ttyd LAN 重连脚本、SQM `wan` 默认值、QuickStart 兼容提示和 `0.1.0-beta.3` 版本号。初次运行应因这些内容尚不存在而失败。

- [ ] **Step 2: 验证测试确实失败**

Run: `bash tests/test-istore-remediation.sh`

Expected: 非零退出，并明确列出第一个缺失契约，而不是语法错误。

- [ ] **Step 3: 接入总测试入口**

在 `tests/test-builder.sh` 开头调用：

```sh
bash "$repo_root/tests/test-istore-remediation.sh"
```

- [ ] **Step 4: 提交测试基线**

```bash
git add docs/KNOWN-ISSUES-ISTORE-BETA2.md tests/test-istore-remediation.sh tests/test-builder.sh
git commit -m "test: capture iStore beta2 remediation contract"
```

### Task 2: 清除无效 APK 运行时软件源

**Files:**
- Create: `files/usr/libexec/re-ss-01-normalize-apk-feeds`
- Create: `files/etc/uci-defaults/98-re-ss-01-apk-feeds`
- Modify: `tests/test-istore-remediation.sh`
- Modify: `docs/KNOWN-ISSUES-ISTORE-BETA2.md`

**Interfaces:**
- Consumes: `/etc/apk/repositories.d/*.list`。
- Produces: 只移除 9 个已确认不存在的 LibWrt 镜像仓库，保留 target、base、luci、packages、routing、telephony 和 `https://istore.istoreos.com/repo-apk/all/compat/packages.adb`。

- [ ] **Step 1: 建立损坏软件源夹具**

测试临时目录至少包含 9 条失败 URL、6 条官方有效 URL 和 1 条 iStore compat URL。断言修复前检测命令返回非零。

- [ ] **Step 2: 实现精确清理脚本**

`re-ss-01-normalize-apk-feeds` 只匹配 URL 路径中的以下 feed 名称：

```text
istore mosdns nas nas_luci nss_packages passwall2 passwall_packages sqm_scripts_nss video
```

脚本用临时文件原子替换，保留原文件权限、注释、顺序和所有不匹配行；重复运行结果必须相同。

- [ ] **Step 3: 首次启动调用清理脚本**

`98-re-ss-01-apk-feeds` 调用 `/usr/libexec/re-ss-01-normalize-apk-feeds`，成功后退出 0。不得执行联网更新，不得启用服务。

- [ ] **Step 4: 验证精确性和幂等性**

Run: `bash tests/test-istore-remediation.sh`

Expected: 9 条失败 URL 全部删除；7 组有效源逐字保留；第二次运行无 diff。

- [ ] **Step 5: 提交软件源修复**

```bash
git add files/usr/libexec/re-ss-01-normalize-apk-feeds files/etc/uci-defaults/98-re-ss-01-apk-feeds tests/test-istore-remediation.sh docs/KNOWN-ISSUES-ISTORE-BETA2.md
git commit -m "fix: remove unavailable runtime apk feeds"
```

### Task 3: 闭环 PassWall2 Xray 启动目录竞态

**Files:**
- Create: `.github/scripts/harden-passwall2-xray.sh`
- Modify: `.github/workflows/build-re-ss-01.yml`
- Modify: `tests/test-istore-remediation.sh`
- Modify: `docs/KNOWN-ISSUES-ISTORE-BETA2.md`

**Interfaces:**
- Consumes: `openwrt/feeds/passwall2/luci-app-passwall2/root/usr/share/passwall2/utils.sh`、`/usr/bin/xray` 和 `/tmp/etc/passwall2/bin/xray`。
- Produces: Xray 目标文件可执行、临时链接可重建、节点 URL 测试不因权限检查失败。

- [x] **Step 1: 在真机收集无修改证据**

以 root 终端运行：

```sh
ls -l /usr/bin/xray /tmp/etc/passwall2/bin/xray
readlink -f /tmp/etc/passwall2/bin/xray
test -x /usr/bin/xray && echo usr-executable || echo usr-not-executable
test -x /tmp/etc/passwall2/bin/xray && echo tmp-executable || echo tmp-not-executable
mount | grep -E ' on /tmp | on / '
/usr/bin/xray version
/tmp/etc/passwall2/bin/xray version
```

已完成：`/usr/bin/xray` 与 `/tmp/etc/passwall2/bin/xray` 可执行，链接指向 `/usr/bin/xray`，`/tmp` 不是 `noexec`，两个路径均可运行 `xray version`。启动项保持禁用是既定策略；手动启动后 Core、Xray、DNS 和 Dnsmasq 均正常，旧权限错误没有新增。

- [ ] **Step 2: 为已确认分支写失败测试**

测试必须验证 `harden-passwall2-xray.sh` 拒绝未知版本的 `utils.sh`，并只对已固定上游版本执行以下两项：在每次调用前创建 `${TMP_BIN_PATH}`；把 `ln -s` 改为可重复替换陈旧链接的 `ln -sfn`。不改变 Xray 包权限，不取消 `/tmp` 的 `noexec` 安全属性，也不把 PassWall2 改成默认自启。

- [ ] **Step 3: 在 feeds 安装后应用补丁**

在工作流的 `Install feeds` 后、`make defconfig` 前调用：

```sh
bash .github/scripts/harden-passwall2-xray.sh openwrt/feeds/passwall2/luci-app-passwall2
```

脚本必须像 QuickStart hardener 一样校验上游原文；遇到未知上游差异直接使构建失败。

- [ ] **Step 4: 真机验证两个协议路径**

分别运行一次 Reality 和 Hysteria2 节点测试，随后检查：

```sh
pgrep -af xray
logread | grep -Ei 'passwall2|xray|permission|执行权限'
```

Expected: 不再出现新的执行权限错误；页面 Core 状态与实际 Xray 进程一致，旧日志允许保留。

- [ ] **Step 5: 提交 PassWall2 修复**

```bash
git add .github/scripts/harden-passwall2-xray.sh .github/workflows/build-re-ss-01.yml tests/test-istore-remediation.sh docs/KNOWN-ISSUES-ISTORE-BETA2.md
git commit -m "fix: preserve PassWall2 Xray executability"
```

### Task 4: 补齐 Samba，保持存储安全边界

**Files:**
- Modify: `configs/re-ss-01-istore.config`
- Modify: `.github/scripts/required-packages.sh`
- Modify: `files/etc/uci-defaults/99-re-ss-01-services`
- Modify: `tests/test-istore-remediation.sh`
- Create: `docs/STORAGE.md`

**Interfaces:**
- Consumes: LibWrt 的 `luci-app-samba4`、`samba4-server`、`block-mount` 包。
- Produces: LuCI Samba 页面存在，服务默认关闭，不创建匿名共享，不自动格式化数据盘。

- [ ] **Step 1: 写缺包失败测试**

断言 iStore 配置和 required-packages 同时包含：

```text
luci-app-samba4
samba4-server
block-mount
```

并断言 defaults 脚本包含 `samba4 disable`。

- [ ] **Step 2: 加入包并保持默认关闭**

只修改 iStore 变体；Argon 变体不因本任务增加 Samba。`99-re-ss-01-services` 将 `samba4` 加入禁用列表，但不生成共享、不改防火墙。

- [ ] **Step 3: 编写存储使用文档**

`docs/STORAGE.md` 固定以下策略：先用 UUID 和文件系统类型核验约 3.98 GiB 数据分区；确认无用户数据后才允许挂载到 `/mnt/storage`；Docker 使用 `/mnt/storage/docker`，Samba 使用 `/mnt/storage/share`；512 MiB swap 默认关闭，只有确认分区身份后才以低优先级启用，不自动格式化。

- [ ] **Step 4: 验证包与默认状态**

Run: `bash tests/test-builder.sh`

Expected: 配置、manifest 契约和默认关闭策略全部通过。

- [ ] **Step 5: 提交 Samba 与存储文档**

```bash
git add configs/re-ss-01-istore.config .github/scripts/required-packages.sh files/etc/uci-defaults/99-re-ss-01-services tests/test-istore-remediation.sh docs/STORAGE.md
git commit -m "feat: add disabled-by-default Samba support"
```

### Task 4b: 校验 Samba4 rpcd ACL 安全修复

**Files:**
- Create: `.github/scripts/verify-samba4-acl.sh`
- Create: `tests/fixtures/samba4/luci-app-samba4.json`
- Modify: `.github/workflows/build-re-ss-01.yml`
- Modify: `tests/test-istore-remediation.sh`

- [x] **Step 1: 先写失败测试**

测试同时覆盖已修复的 `/usr/sbin/smbd -V` ACL 和旧的 `/usr/sbin/smbd` 直接执行 ACL；旧 ACL 必须被拒绝且原文件不能被改写。

- [x] **Step 2: 接入严格构建校验**

工作流在 feeds 安装后、iStore 变体中检查 JSON 有效性、危险路径不存在且安全版本探针恰好出现一次。当前 LibWrt 固定的 ImmortalWrt LuCI 提交已返回安全版本探针形式。

### Task 5: 修复 ttyd LAN 重载后的可达性

**Files:**
- Create: `files/etc/hotplug.d/iface/95-ttyd-lan-rebind`
- Modify: `tests/test-istore-remediation.sh`
- Modify: `SECURITY.md`

**Interfaces:**
- Consumes: netifd 的 `ACTION` 与 `INTERFACE` 环境变量。
- Produces: 仅在 `lan` 的 `ifup`/`ifupdate` 后重启已启用的 ttyd；不开放 WAN。

- [ ] **Step 1: 写事件过滤失败测试**

测试用伪造的 `/etc/init.d/ttyd` 记录调用次数，验证 `wan`、`ifdown` 和未知事件均不重启；只有 `lan + ifup/ifupdate` 调用一次。

- [ ] **Step 2: 实现去抖动热插拔脚本**

脚本使用 `/tmp/ttyd-lan-rebind.lock` 防止同一轮网络事件重复重启，确认 `/etc/init.d/ttyd enabled` 和 `running` 后才执行 restart，并写入单条 `logger -t ttyd-rebind` 记录。

- [ ] **Step 3: 验证安全边界**

静态测试拒绝脚本出现 `firewall`, `wan`, `0.0.0.0` accept 规则；`SECURITY.md` 明确 ttyd 只允许 LAN。

- [ ] **Step 4: 真机网络重载验收**

仅在已有恢复通道时执行一次 LAN reload，10 秒后从 LAN 访问 `http://<LAN-IP>:7681/`；同时从 WAN 侧探测应失败。检查 ttyd PID 已更新且网络没有第二次循环重载。

- [ ] **Step 5: 提交 ttyd 修复**

```bash
git add files/etc/hotplug.d/iface/95-ttyd-lan-rebind tests/test-istore-remediation.sh SECURITY.md
git commit -m "fix: rebind ttyd after LAN reload"
```

### Task 6: 修正 SQM 默认接口并限制 NSS 冲突

**Files:**
- Modify: `files/etc/uci-defaults/99-re-ss-01-services`
- Modify: `tests/test-istore-remediation.sh`
- Modify: `docs/VARIANTS.md`

**Interfaces:**
- Consumes: `sqm.@queue[0]`。
- Produces: SQM 保持禁用，默认接口为 `wan`；文档要求启用 SQM 时单独验证 NSS/offload。

- [ ] **Step 1: 写默认接口失败测试**

断言 defaults 包含：

```sh
uci -q set sqm.@queue[0].interface='wan'
uci -q set sqm.@queue[0].enabled='0'
uci -q commit sqm
```

- [ ] **Step 2: 写入最小默认值修复**

只改默认接口和启用状态，不预设带宽，不自动关闭 NSS，不启用队列。

- [ ] **Step 3: 真机兼容性验收**

先记录关闭 SQM 时的 NSS 状态和吞吐；再只启用一个 `wan` 队列，验证延迟、吞吐、CPU 和 NSS/offload 状态；验收后恢复默认关闭。

- [ ] **Step 4: 提交 SQM 修复**

```bash
git add files/etc/uci-defaults/99-re-ss-01-services tests/test-istore-remediation.sh docs/VARIANTS.md
git commit -m "fix: target SQM defaults at WAN"
```

### Task 7: 为 QuickStart 错误数据提供可靠兼容层

**Files:**
- Create: `.github/scripts/harden-quickstart-status-ui.sh`
- Create: `tests/fixtures/quickstart/main.htm`
- Modify: `.github/workflows/build-re-ss-01.yml`
- Modify: `tests/test-istore-remediation.sh`
- Modify: `docs/VARIANTS.md`

**Interfaces:**
- Consumes: `openwrt/feeds/nas_luci/luci/luci-app-quickstart/luasrc/view/quickstart/main.htm`。
- Produces: RE-SS-01 兼容提示，明确标准 LuCI“状态”和“挂载点”页面为温度与可写空间权威来源。

- [ ] **Step 1: 固定上游模板并写失败测试**

把当前 QuickStart `main.htm` 保存为 fixture。测试要求 hardener 仅接受该原文或已补丁版本；上游模板变化时构建失败，避免静默修改未知页面。

- [ ] **Step 2: 注入兼容提示而不修改闭源后端**

在 `#app` 前加入仅针对 RE-SS-01 的提示：QuickStart 的 CPU 温度和整盘容量可能不准确；CPU/Wi-Fi 温度以 `/admin/status/overview` 为准，可写空间以 `/admin/system/mounts` 的 `/overlay` 为准。不得用 MutationObserver 篡改数值，也不得修改压缩后的 `index.js`。

- [ ] **Step 3: 在现有 QuickStart hardening 后调用**

工作流调用：

```sh
bash .github/scripts/harden-quickstart-status-ui.sh openwrt/feeds/nas_luci/luci/luci-app-quickstart
```

- [ ] **Step 4: 验证页面与安全性**

Run: `bash tests/test-istore-remediation.sh`

Expected: 提示只出现一次，链接均为站内 LuCI 路径，未引入外部脚本、网络设置写入或敏感信息。

- [ ] **Step 5: 提交 QuickStart 兼容层**

```bash
git add .github/scripts/harden-quickstart-status-ui.sh tests/fixtures/quickstart/main.htm .github/workflows/build-re-ss-01.yml tests/test-istore-remediation.sh docs/VARIANTS.md
git commit -m "fix: clarify QuickStart status data on RE-SS-01"
```

### Task 8: 发布 beta.3 并执行真机验收

**Files:**
- Modify: `versions/istore.version`
- Modify: `CHANGELOG.md`
- Modify: `docs/RELEASES.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: Tasks 1–7 的测试、配置与 rootfs overlay。
- Produces: 不覆盖 beta.2 的 `re-ss-01-istore-v0.1.0-beta.3` prerelease 和完整验收记录。

- [ ] **Step 1: 运行完整本地测试**

Run: `bash tests/test-builder.sh`

Expected: 所有现有测试和 remediation 测试通过，工作树只包含计划内文件。

- [ ] **Step 2: 更新版本和变更记录**

把 `versions/istore.version` 改为：

```text
0.1.0-beta.3
```

CHANGELOG 必须逐项列出 APK、PassWall2、Samba、ttyd、SQM 和 QuickStart 兼容修复，并注明存储分区/swap 仍不自动启用。

- [ ] **Step 3: 提交发布元数据**

```bash
git add versions/istore.version CHANGELOG.md docs/RELEASES.md README.md
git commit -m "release: prepare iStore dashboard beta3"
```

- [ ] **Step 4: 推送分支并启动 iStore 云编译**

Run: `git push origin feature/istoreos-quickstart`

在 GitHub Actions 的 `Build JDCloud RE-SS-01` 中选择 `istore`。不得选择 Argon，不得覆盖 beta.2 标签。

- [ ] **Step 5: 验证发布产物**

确认 Release 为 prerelease、非 Latest；`SHA256SUMS` 覆盖 factory、sysupgrade、initramfs、manifest、build config 和元数据；manifest 包含 Samba、PassWall2、Xray、ttyd、SQM 与 QuickStart 必需包。

- [ ] **Step 6: 分两阶段真机验收**

第一阶段使用 sysupgrade 并保留当前 `192.168.100.1` 配置，验证管理面、WAN、DNS、DHCP、双频 Wi-Fi、软件源、PassWall2、Samba 页面和 ttyd。第二阶段只有在备份和 U-Boot Web 恢复通道都确认可用时，才做恢复默认配置验收。

- [ ] **Step 7: 稳定性观察**

连续观察至少 30 分钟，并完成一次软件重启和一次断电重启。验收日志不得出现自动 LAN 重载、Xray 执行权限错误、APK 仓库下载错误或 OOM。

- [ ] **Step 8: 发布决策**

若全部 beta.3 门槛通过，更新 `docs/KNOWN-ISSUES-ISTORE-BETA2.md` 为“已在 beta.3 修复”并附实机证据；若任一 P0 失败，保留 prerelease 且不推荐刷写，不合并到 `main`。

## Self-Review

- Spec coverage: 保留双变体、版本隔离、prerelease、默认关闭和恢复主题规则；本计划不修改 Argon 稳定线。
- Placeholder scan: 无 TBD/TODO；每个任务都有明确文件、测试、实现边界和提交。
- Type/interface consistency: 所有构建脚本均在 feeds 安装后、`make defconfig` 前运行；rootfs overlay 统一位于 `files/`；测试统一由 `tests/test-builder.sh` 汇总。
