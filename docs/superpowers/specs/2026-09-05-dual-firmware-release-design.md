# 京东云 AX1800 PRO（RE-SS-01）双固件版本管理设计

## 目标

把现有仓库整理为京东云 AX1800 PRO（机身型号 `RE-SS-01`）的专用 LibWrt 云编译项目，在不破坏已验证 Argon 固件的前提下，增加带 iStoreOS QuickStart 首页、iStore 软件中心和 LuCI Web 终端的实验固件。

本设计只管理 `jdcloud,re-ss-01`。源码继续使用 `LiBwrt/LibWrt` 的 `25.12-nss` 分支，并保留 RE-SS-01 factory 镜像的 64 KiB 对齐处理。

## 项目命名

- GitHub 仓库名：`JDCloud-AX1800-Pro-RE-SS-01`
- 中文展示名：`京东云 AX1800 PRO（RE-SS-01）`
- 上游源码：`LiBwrt/LibWrt`
- 默认分支：`main`

仓库改名后更新本地 `origin`、README、工作流标题和 Release 链接。旧 Release 不删除，现有可用版本 `re-ss-01-4-1` 继续作为迁移前的恢复基线。

## 版本模型

仓库使用一个稳定主分支和两个配置档案，不永久维护两套相互分叉的源码。

### Argon 稳定版

- 变体标识：`argon`
- 初始产品版本：`1.0.0`
- 定位：当前已在真机验证可启动的稳定版本
- 默认界面：Argon
- 后备界面：Bootstrap
- Release 类型：正式版
- 允许标记为 GitHub Latest

### iStoreOS Dashboard 实验版

- 变体标识：`istore`
- 初始产品版本：`0.1.0-beta.1`
- 定位：在稳定版基础上增加 QuickStart、iStore 和 Web 终端
- 默认 LuCI 主题：Argon
- 后备界面：Bootstrap
- QuickStart：首个 beta 通过菜单访问，不强制接管登录后的默认落地页
- Release 类型：Prerelease
- 不得标记为 GitHub Latest

产品版本保存在仓库内的独立版本文件中。发布同一版本号前必须先更新版本文件；工作流发现对应标签已存在时应在编译前失败，避免覆盖或产生含义不明的重复 Release。

## 分支策略

- `main`：只保存通过仓库测试的构建体系和可复现的双配置。
- `feature/istoreos-quickstart`：首次移植 QuickStart、iStore 和终端的短期开发分支。
- 功能分支完成云编译和静态产物检查后仍保持为 beta；真机验收通过后才能合并回 `main`。
- 两个固件变体最终由 `main` 中的两个配置文件产生，而不是长期保留 `argon`、`istore` 两条容易漂移的分支。

计划使用以下配置和版本文件：

```text
configs/re-ss-01-argon.config
configs/re-ss-01-istore.config
versions/argon.version
versions/istore.version
```

## 软件包边界

两个变体都保留当前稳定版组件：

- PassWall2（Xray、nftables）
- MosDNS、AdGuard Home
- nlbwmon
- Docker 与 Dockerman
- Tailscale
- SQM 与 NSS SQM 脚本
- Argon、Bootstrap、简体中文

`istore` 变体额外包含：

- `luci-app-ttyd`
- `luci-app-store`
- `quickstart`
- `luci-app-quickstart`

QuickStart 的软件包依赖由编译系统解析，不在配置中手工重复列出。iStore 和 QuickStart 使用独立 feed，并固定仓库与分支来源，避免上游默认 feed 顺序覆盖 MosDNS、PassWall2 或基础 LuCI 包。

## 默认服务策略

两种固件都继续遵循现有低风险启动策略：

- PassWall2、MosDNS、AdGuard Home、Docker、Tailscale、SQM 默认关闭。
- nlbwmon 默认启用，数据库只保留 3 期。
- iStoreOS Dashboard 版中 QuickStart 可运行以提供首页数据。
- `ttyd` 只允许从 LAN 侧通过 LuCI 使用，不新增 WAN 防火墙入口。
- 固件不预置代理节点、账户、证书、密码或云服务凭据。
- 固件不自动挂载 `storage`、不启用 swap，也不改变 LAN 默认地址；这些属于真机验收后的独立配置任务。

## 云编译入口

保留一个 GitHub Actions 工作流，在手动运行时提供 `variant` 选择：

- `argon`
- `istore`

工作流根据变体选择配置文件、版本文件、必需包清单、Artifact 名称和 Release 类型。两种变体共用上游克隆、缓存、factory 对齐、编译和校验流程，避免维护两份工作流。

编译前必须验证：

1. 目标设备只有 `jdcloud_re-ss-01`。
2. 上游为 `LiBwrt/LibWrt:25.12-nss`。
3. 配置档案与版本文件存在。
4. 目标 Release 标签不存在。
5. 变体所需包在 `make defconfig` 后仍为启用状态。

编译后必须验证：

1. factory、sysupgrade、initramfs 和 manifest 均存在。
2. factory 大小能被 65536 整除。
3. manifest 含有变体必需包。
4. 生成 SHA-256 清单。
5. Release 说明记录上游提交、构建配置提交、产品版本和变体。

## Release 与文件命名

标签格式：

```text
re-ss-01-argon-v1.0.0
re-ss-01-istore-v0.1.0-beta.1
```

Release 标题格式：

```text
京东云 AX1800 PRO（RE-SS-01）· Argon v1.0.0
京东云 AX1800 PRO（RE-SS-01）· iStoreOS Dashboard v0.1.0-beta.1
```

发布后的固件文件统一重命名，使设备、源码、变体、版本和用途均可从文件名识别：

```text
jdcloud-re-ss-01-libwrt-argon-v1.0.0-squashfs-factory.bin
jdcloud-re-ss-01-libwrt-argon-v1.0.0-squashfs-sysupgrade.bin
jdcloud-re-ss-01-libwrt-istore-v0.1.0-beta.1-squashfs-factory.bin
jdcloud-re-ss-01-libwrt-istore-v0.1.0-beta.1-squashfs-sysupgrade.bin
```

factory 用于当前已验证的 U-Boot Web 首次/恢复刷写路径；sysupgrade 只用于确认分区布局兼容后的 LuCI/命令行升级。文档必须同时给出 SHA-256，不能只根据文件名刷写。

## 文档结构

- `README.md`：项目定位、两个变体、当前推荐下载和快速入口。
- `docs/VARIANTS.md`：组件、默认服务、资源占用和成熟度对比。
- `docs/BUILD.md`：云编译选择、版本更新和失败处理。
- `docs/FLASHING.md`：U-Boot Web、factory/sysupgrade 区别、校验和救砖提醒。
- `docs/RELEASES.md`：版本号、标签、文件名和 Latest/Prerelease 规则。
- `CHANGELOG.md`：按产品版本记录用户可见变化。
- `SECURITY.md`：root 密码、LuCI、SSH、ttyd 和 WAN 暴露边界。

## 故障隔离与回退

- iStoreOS Dashboard 构建失败不得影响 Argon 配置和现有 Release。
- QuickStart 页面异常时仍可直接进入标准 LuCI 状态页，并切换 Argon 或 Bootstrap。
- iStore 软件源或应用不兼容时不得阻止 LuCI、SSH、WAN、LAN 或无线网络启动。
- beta 真机验收失败时保留失败记录，但不将其标记为 Latest；恢复使用已验证 Argon factory 镜像。
- 不自动刷写路由器，不自动修改当前路由器配置。

## 验收标准

仓库级验收：

- 构建契约测试覆盖两个配置、版本文件、feed 顺序、标签和文件命名。
- 测试先证明缺失的新行为会失败，再通过最小实现使其通过。
- 工作流 YAML 可解析，shell 脚本语法检查通过，工作区无意外文件。

云端验收：

- `istore` 变体在 GitHub Actions 完整编译成功。
- Release 为 prerelease，产物齐全且 factory 对齐。
- manifest 明确包含 QuickStart、iStore、LuCI ttyd 和全部公共组件。

真机验收：

- RE-SS-01 能通过 U-Boot Web 写入并正常重启。
- 标准 LuCI、Argon 和 Bootstrap 均可访问。
- QuickStart 页面能显示 WAN、接口、内存和 eMMC/overlay 信息。
- iStore 能加载软件列表；单个第三方应用仍按兼容性单独验收。
- LuCI 终端可从 LAN 打开，WAN 无法访问。
- Docker、代理、DNS、Tailscale 和 SQM 保持预定默认状态。
- 至少完成一次重启与断电重启验证。

首个 beta 通过以上真机验收后，另行决定是否让 QuickStart 接管登录后的默认首页。该决定不与首次移植捆绑。

