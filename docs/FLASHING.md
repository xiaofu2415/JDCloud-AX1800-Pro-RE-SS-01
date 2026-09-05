# 刷写与恢复指南

刷机可能造成设备无法启动、配置丢失或设备特有分区损坏。这里只说明文件选择和安全边界，不代替针对当前 U-Boot、分区布局和设备状态的现场判断。

## 刷写前必须完成

1. 核对机身型号确实为京东云 AX1800 PRO `RE-SS-01`。其他 IPQ60xx 设备不能使用这些镜像。
2. 备份 ART、EEPROM、MAC、校准数据等设备特有分区，并确认备份可以读取。
3. 准备可用的 U-Boot Web 恢复入口、有线连接和断电恢复方案。
4. 下载目标 Release 的固件和同一 Release 中的 `SHA256SUMS`。
5. 核对所选变体、版本与用途，并完成 SHA-256 校验。

## factory 与 sysupgrade

- `squashfs-factory.bin`：用于已经验证过的 U-Boot Web 首次刷写或恢复路径。本项目会将 RE-SS-01 factory 镜像对齐到 64 KiB。factory 并不代表可以在任何厂商后台直接上传；必须确认当前 U-Boot 和分区布局与该路径一致。
- `squashfs-sysupgrade.bin`：只用于已经运行兼容 LibWrt/OpenWrt、且确认分区布局匹配时，通过 LuCI 或命令行升级。不能把 sysupgrade 当作未知原厂布局的首次刷入镜像。

无法确认当前分区布局时，应停止刷写并先恢复到已知基线。不要凭文件名猜测，更不要将其他机型的 factory 或 sysupgrade 文件用于 RE-SS-01。

## SHA-256 校验

在包含固件与 `SHA256SUMS` 的目录执行：

```bash
# Linux
sha256sum -c SHA256SUMS

# macOS
shasum -a 256 -c SHA256SUMS
```

只有目标固件显示校验成功、文件名与目标 Release 完全一致时才可继续。校验失败、文件为空、文件名被手工改动或清单来自另一版本时都必须重新下载。

## 迁移与恢复基线

旧 Release `re-ss-01-4-1` 是本项目迁移前的恢复基线，应保留，不要删除。当前稳定推荐是已刷入并验证过的 Argon `1.0.0`；iStore `0.1.0-beta.1` 在完整真机验收前仍是 beta。

若 iStore beta 无法启动、管理页面异常或基础网络失效，请保留失败信息，通过已验证的 U-Boot Web 恢复路径刷回 Argon factory 镜像。QuickStart 单独异常时，可先尝试标准 LuCI 状态页 `/cgi-bin/luci/admin/status/overview`；其他页面仍由 Argon 提供，必要时可使用 Bootstrap 恢复主题。

## 刷后检查

- 首次登录后立即设置安全的 root 密码；固件不提供默认账户密码。
- 确认 LAN、WAN、无线、SSH 和标准 LuCI 正常。
- iStore 变体确认 QuickStart 为落地页，标准 LuCI 页面由 Argon 渲染。
- 确认 ttyd 只从 LAN 侧可用，WAN 侧不可访问。
- 确认 PassWall2、MosDNS、AdGuard Home、Docker、Tailscale 与 SQM 保持关闭，nlbwmon 启用且保留 3 期。
- 至少执行一次普通重启和一次断电重启。

云构建不会自动刷写路由器，也不会更改或上传路由器数据。任何实际刷写都必须由设备所有者在本地明确执行。
