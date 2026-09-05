# 变更记录

本文件按产品版本记录用户可见变化。Argon 与 iStoreOS Dashboard 使用独立版本线。

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
