# 变更记录

本文件按产品版本记录用户可见变化。Argon 与 iStoreOS Dashboard 使用独立版本线。

## 0.1.0-beta.4

- 修复 GitHub Actions 下载清理步骤递归删除 `openwrt/dl/go-mod-cache` 中小于 1 KiB 的 Go 源文件，避免 AdGuard Home 报告 `internal/*` 依赖不存在。
- 提升下载缓存 schema 到 `go-mod-cache-v2`，淘汰 beta.3 运行产生的损坏模块缓存；保留 PassWall2、QuickStart、Samba 和 ttyd 的 beta.3 修复。
- 继续保持 iStore 为 Prerelease，PassWall2、MosDNS、AdGuard Home、Docker、Tailscale、Samba 和 SQM 默认关闭。

## 0.1.0-beta.3

- 修复 PassWall2 启动前运行目录初始化和 Xray 临时链接替换逻辑；PassWall2 仍默认关闭，手动启动后才接管流量。
- 清理已确认失效的 9 个运行时 APK 软件源，保留官方源与 iStore compat 源。
- iStore 变体加入 `luci-app-samba4`、`samba4-server` 和 `block-mount`；Samba 默认关闭，不创建共享或开放端口。
- 构建阶段拒绝带有 `/usr/sbin/smbd` 直接 `file.exec` 只读 ACL 的旧 Samba LuCI 源，只接受限制为 `/usr/sbin/smbd -V` 的安全 ACL。
- LAN 地址重载后为 ttyd 增加 LAN 侧安全重绑定和去抖；不新增 WAN 入口。
- 将 SQM 默认接口改为 `wan`，继续默认关闭，并保留 NSS 兼容性单独验收要求。
- QuickStart 首页增加 RE-SS-01 兼容提示：CPU/Wi-Fi 温度以标准 LuCI 状态页为准，可写空间以 `/overlay` 挂载点为准。
- `storage` 分区和 swap 仍不自动挂载、格式化或启用，Docker 与 Samba 数据目录须在核验分区后手动配置。
- 本版本仍为 Prerelease；云编译成功后必须完成真机启动、网络、服务、重启和断电重启验收。

## 0.1.0-beta.2

- 禁用 QuickStart 的 `startdhns` 自动改网服务及 WAN 接口事件钩子，避免开机或网络重载时改写 RE-SS-01 的 LAN、WAN 与 DHCP 配置。
- 保留 QuickStart Dashboard、iStore 软件中心、Argon 标准 LuCI 页面和 LAN 侧 Web 终端。
- 网络配置统一交给标准 LuCI；QuickStart 网络向导在此设备上不受支持。
- `0.1.0-beta.1` 已出现重启后 DHCP、ARP、LAN 和管理后台网络失效，停止推荐并保留为问题复现记录。

## 0.1.0-beta.1

- 首个 iStoreOS Dashboard 实验版本。
- 新增 QuickStart 登录落地首页；普通 LuCI 页面继续使用 Argon，Bootstrap 作为恢复主题。
- 新增 iStore 软件中心与 LAN 侧 LuCI Web 终端组件。
- 保留 Argon 稳定版的公共网络、DNS、容器、Tailscale、SQM 与流量统计组件。
- 发布类型固定为 Prerelease，且不设为 GitHub Latest。
- 云构建成功后仍需完成 RE-SS-01 真机物理验收，才能考虑合并到 `main`。

## 1.0.0

- 建立 Argon 稳定产品版本线。
- 保留已在 RE-SS-01 真机验证可启动的 Argon 固件配置。
- 标准 LuCI 页面默认使用 Argon，并保留 Bootstrap 恢复主题。
- PassWall2、MosDNS、AdGuard Home、Docker、Tailscale 和 SQM 首次启动保持关闭；nlbwmon 启用并保留 3 期数据库。
- 正式 Release 可标记为 GitHub Latest，作为 iStore beta 完成硬件验收前的稳定推荐。
