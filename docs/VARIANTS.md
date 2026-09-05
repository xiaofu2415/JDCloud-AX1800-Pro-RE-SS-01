# 固件变体说明

本仓库使用同一套构建脚本和同一条 `main` 分支维护两个配置档案。两者都基于 `LiBwrt/LibWrt:25.12-nss`，且只面向京东云 AX1800 PRO（RE-SS-01）。

## 对比

| 项目 | Argon | iStoreOS Dashboard |
| --- | --- | --- |
| 变体标识 | `argon` | `istore` |
| 当前版本 | `1.0.0` | `0.1.0-beta.1` |
| 成熟度 | 已刷入真机并验证可启动的稳定版 | 等待完整真机验收的 beta |
| 登录落地页 | 标准 LuCI 页面 | QuickStart 首页（默认落地页） |
| 普通管理页 | Argon 渲染标准 LuCI 页面 | Argon 渲染标准 LuCI 页面 |
| 恢复主题 | Bootstrap | Bootstrap |
| 额外组件 | 无 | QuickStart、iStore、LuCI Web 终端 |
| Release | 正式版，可为 Latest | Prerelease，永不为 Latest |
| 资源占用 | 稳定基线 | 因增加应用和依赖，预期高于 Argon；须以真机数据确认 |

QuickStart 是 iStore 变体的首页应用和登录落地页，不是完整的 LuCI 主题。网络、系统、服务和插件等标准 LuCI 页面仍由 Argon 显示；不存在一个单独的“Argon 首页”入口。

在 iStore beta 完成启动、网络、页面、重启与断电重启等硬件验收前，Argon `1.0.0` 仍是稳定推荐。不要把云端编译成功视为物理设备验证通过。

## 共同组件与默认服务

两种变体都包含：

- PassWall2（Xray、nftables）
- MosDNS 与 AdGuard Home
- nlbwmon
- Docker 与 Dockerman
- Tailscale
- SQM 与 NSS SQM 脚本
- Argon、Bootstrap 和简体中文

首次启动时，PassWall2、MosDNS、AdGuard Home、Docker、Tailscale 和 SQM 保持禁用；nlbwmon 启用并只保留 3 期数据库。固件不会预置代理节点、账户、证书、密码或云服务凭据，也不会自动挂载 `storage`、启用 swap 或更改 LAN 默认地址。

## iStore 兼容性边界

iStore 软件列表可以加载，但 iStore 中的单个应用不保证兼容 LibWrt 25.12 或本设备。某个商店应用安装失败或运行异常，不应被解读为 LuCI、LAN、WAN、SSH 或无线网络本身不可用；每个第三方应用都需要单独验证。

iStore 变体中的 ttyd 仅计划供 LAN 侧通过 LuCI 使用，不新增 WAN 防火墙入口。是否确实无法从 WAN 访问，必须在真机验收中确认。
