# 构建指南

本项目只提供手动触发的 GitHub Actions 构建。工作流固定使用 `LiBwrt/LibWrt` 的 `25.12-nss` 分支，并固定目标为 `jdcloud_re-ss-01`。

## 手动选择变体

1. 打开 [仓库 Actions](https://github.com/xiaofu2415/JDCloud-AX1800-Pro-RE-SS-01/actions)。
2. 选择 **Build JDCloud RE-SS-01**。
3. 点击 **Run workflow**。
4. 在必选的 `variant` 下拉框中选择 `argon` 或 `istore`：
   - `argon`：使用 `configs/re-ss-01-argon.config` 和 `versions/argon.version`。
   - `istore`：使用 `configs/re-ss-01-istore.config` 和 `versions/istore.version`。
5. 确认分支与选择后开始运行。

不要让两个配置长期分叉成两条产品分支；最终都由 `main` 上的双配置和统一工作流产生。

## 版本更新规则

当前版本文件分别为：

- Argon：`versions/argon.version`，当前 `1.0.0`
- iStore：`versions/istore.version`，当前 `0.1.0-rc.1`

重建同一 Release 前必须先更新对应的版本文件，并提交该版本变更。不得重复使用已有产品版本覆盖 Release；工作流发现精确标签已经存在时，会在安装依赖和编译之前失败。修复后重新发布时应递增版本，例如从 `0.1.0-beta.2` 更新为 `0.1.0-beta.3`，而不是删除旧标签后重用版本号。

## 构建过程与产物

工作流不会自动安装 Docker/Dockerman；两个变体均以无容器运行时的基线构建。若以后需要容器，应先确认 `storage` 分区和内存余量，再另行维护专用变体。

工作流会依次：

1. 解析变体、配置、版本、标签和发布类型。
2. 拒绝已经存在的产品版本标签。
3. 克隆当时最新的 `25.12-nss` 提交并记录源码提交号。
4. 安装公共 feed；只为 `istore` 加入固定的 iStore 与 QuickStart feed。
5. 对 PassWall2 的运行目录/临时 Xray 链接、默认直连分流映射、Samba4 rpcd ACL、RE-SS-01 CPU thermal-zone 读取端点、nlbwmon conntrack-netlink 启动顺序和 iStore QuickStart 状态模板执行内容校验 hardener；若上游实现发生未知变化或出现危险 ACL 则停止构建。
6. 对 `luci-mod-status` 信道分析图表执行隐藏标签布局 hardener；仅对 `istore` 禁用 QuickStart 的自动改网服务与 WAN 事件钩子、移除 Docker 能力卡片，并加入 Samba（默认关闭）；若上游实现发生未知变化则停止构建。
7. 载入所选配置并在 `make defconfig` 后验证必需包。
8. 编译、执行 RE-SS-01 factory 64 KiB 对齐、收集并校验发布文件。
9. 生成 `BUILD-METADATA.txt` 与 `SHA256SUMS`，然后按变体发布。

Artifact 保留已校验的 factory、sysupgrade、initramfs、manifest、`profiles.json`、`build.config`、构建元数据和 SHA-256 清单。实际源代码提交号与构建仓库提交号都写入构建元数据及 Release 说明。

## 数据与设备边界

构建器不会自动刷写固件，也不会上传任何路由器数据。它不连接当前路由器，不修改 LAN 地址、服务、挂载、swap 或其他运行中配置。固件本身仅携带已核验 UUID 的 fstab 条目，不包含格式化、覆盖或扫描未知分区的命令。无需提供路由器密码、个人访问令牌或路由器备份。

即使 RC 编译成功，也必须完成真机硬件验证后，才允许合并到 `main`。物理验收至少应覆盖启动、标准 LuCI、Argon、Bootstrap、QuickStart、iStore 列表、Samba 页面、LAN 侧终端、WAN 隔离、默认服务、`/mnt/storage` 挂载、swap、重启与断电重启。PassWall2 手动启动时应确认 Xray 运行目录存在、Core 状态与实际进程一致、`DirectFront`/`DirectGame` 已写入活动配置，并在 Reality 与 Hysteria2 各运行至少 30 分钟检查 OOM；旧日志中的权限错误不能替代当前启动结果。固件不会启用未知 swap，OOM 验收通过前不得宣称已消除内存风险。修复后的启动同步与分流映射可用 `bash tests/test-passwall2-policy.sh` 独立回归。

## 失败处理

- **标签已存在**：更新对应 `versions/*.version` 后重新提交，不要覆盖旧 Release。
- **必需包缺失**：保留失败日志，检查所选配置和固定 feed；不要删掉校验步骤绕过失败。
- **编译失败**：Argon 与 iStore 配置相互独立；iStore 失败不得改写现有 Argon Release。若日志出现 `no required module provides package` 且路径位于 `dl/go-mod-cache`，先检查下载清理是否递归删除了 Go 模块缓存中的小文件；本仓库的工作流只清理 `openwrt/dl` 顶层下载文件，并通过 `DOWNLOAD_CACHE_SCHEMA` 使旧缓存失效。
- **产物校验失败**：不要发布或刷写。确认文件集、manifest、factory 对齐、元数据和 `SHA256SUMS` 全部通过。
- **beta 真机失败**：记录结果并使用已验证的 Argon factory 镜像恢复；不要把 iStore 标为 Latest 或合并到 `main`。

本地提交前运行：

```bash
bash tests/test-builder.sh
```
