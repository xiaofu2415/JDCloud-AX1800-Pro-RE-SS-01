# 京东云 AX1800 PRO（RE-SS-01）

这是 [JDCloud-AX1800-Pro-RE-SS-01](https://github.com/xiaofu2415/JDCloud-AX1800-Pro-RE-SS-01) 的专用 LibWrt 云编译仓库，只构建机身型号为 `RE-SS-01` 的京东云 AX1800 PRO 固件。上游固定为 `LiBwrt/LibWrt` 的 `25.12-nss` 分支，目标设备固定为 `jdcloud_re-ss-01`。

> 本项目不是京东云、LibWrt 或 iStoreOS 的官方固件。刷机有造成设备无法启动和数据丢失的风险，请先备份设备特有分区并准备可用的恢复路径。

## 固件选择

| 变体 | 产品版本 | 状态 | 登录后的页面 | 发布策略 |
| --- | --- | --- | --- | --- |
| Argon | `1.0.0` | 稳定版 | 标准 LuCI 页面使用 Argon | 正式发布，可设为 GitHub Latest |
| iStoreOS Dashboard | `0.1.0-beta.1` | beta 实验版 | QuickStart 首页；其他 LuCI 页面使用 Argon | Prerelease，不得设为 Latest |

Argon 仍是稳定推荐，直到 iStore beta 完成真机硬件验证。当前 iStore 变体尚不能替代已刷入并验证过的 Argon 固件作为稳定选择。

iStore 可以显示软件列表，但其中单个应用不保证兼容 LibWrt 25.12 或 RE-SS-01。构建成功也不等于真机兼容；beta 必须完成物理设备验收后才能合并到 `main`。

## 手动云编译

1. 打开本仓库的 **Actions** 页面并选择 **Build JDCloud RE-SS-01**。
2. 点击 **Run workflow**，在 `variant` 中选择 `argon` 或 `istore`。
3. 等待测试、编译和产物校验完成。
4. 从该次运行的 Artifact 或 [Releases](https://github.com/xiaofu2415/JDCloud-AX1800-Pro-RE-SS-01/releases) 下载与所选变体、版本和用途完全一致的文件。
5. 刷写前根据 `SHA256SUMS` 校验 SHA-256，并确认应该使用 factory 还是 sysupgrade 镜像。

工作流无需个人访问令牌或额外仓库 Secret。它只在 GitHub Actions 中编译和发布文件，不会自动刷写路由器，也不会上传路由器数据。

## 默认服务边界

两个变体都预装 PassWall2、MosDNS、AdGuard Home、nlbwmon、Docker、Tailscale、SQM、Argon、Bootstrap 和简体中文。PassWall2、MosDNS、AdGuard Home、Docker、Tailscale 与 SQM 首次启动保持关闭；nlbwmon 默认启用并保留 3 期数据库。

iStore 变体另外包含 QuickStart、iStore 和 LuCI Web 终端。QuickStart 是落地首页，不是完整主题；标准 LuCI 页面仍由 Argon 渲染，Bootstrap 作为恢复主题。固件不添加默认凭据，也不为 ttyd 新增 WAN 防火墙开放规则。首次登录后必须设置安全的 root 密码。

## 使用指南

- [变体说明](docs/VARIANTS.md)：组件、首页、默认服务、资源与成熟度差异。
- [构建指南](docs/BUILD.md)：手动选择变体、更新版本和处理失败。
- [刷写指南](docs/FLASHING.md)：factory/sysupgrade 区别、SHA-256 校验和恢复基线。
- [发布指南](docs/RELEASES.md)：版本、标签、文件名和 Latest/Prerelease 规则。
- [安全指南](SECURITY.md)：密码、管理界面、ttyd 和 WAN 暴露边界。

用户可见变更记录见 [CHANGELOG.md](CHANGELOG.md)。本地仓库检查使用：

```bash
bash tests/test-builder.sh
```
