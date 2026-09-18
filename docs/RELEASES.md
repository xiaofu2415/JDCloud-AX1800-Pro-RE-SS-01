# 发布与命名规则

本仓库按固件变体分别维护产品版本。版本来自 `versions/argon.version` 与 `versions/istore.version`，不使用 Actions 运行编号代替产品版本。

## 标签与标题

标签格式：

```text
re-ss-01-<variant>-v<version>
```

当前两个精确标签与标题是：

| 变体 | 标签 | Release 标题 |
| --- | --- | --- |
| Argon | `re-ss-01-argon-v1.0.0` | `京东云 AX1800 PRO（RE-SS-01）· Argon v1.0.0` |
| iStore | `re-ss-01-istore-v0.1.0-beta.9` | `京东云 AX1800 PRO（RE-SS-01）· iStoreOS Dashboard v0.1.0-beta.9` |

精确标签已经存在时，工作流必须在编译前失败。重新构建同一发布内容也要先递增对应版本文件；不得覆盖、删除后重用或用运行编号制造含义不清的重复 Release。

迁移前 Release `re-ss-01-4-1` 保留为恢复基线，不纳入新的双变体标签格式。

## 固件文件名

通用前缀为：

```text
jdcloud-re-ss-01-libwrt-<variant>-v<version>
```

当前发布中的 factory 与 sysupgrade 文件名必须精确为：

```text
jdcloud-re-ss-01-libwrt-argon-v1.0.0-squashfs-factory.bin
jdcloud-re-ss-01-libwrt-argon-v1.0.0-squashfs-sysupgrade.bin
jdcloud-re-ss-01-libwrt-istore-v0.1.0-beta.2-squashfs-factory.bin
jdcloud-re-ss-01-libwrt-istore-v0.1.0-beta.2-squashfs-sysupgrade.bin
```

beta.9 当前构建使用以下 iStore 文件名：

```text
jdcloud-re-ss-01-libwrt-istore-v0.1.0-beta.9-squashfs-factory.bin
jdcloud-re-ss-01-libwrt-istore-v0.1.0-beta.9-squashfs-sysupgrade.bin
```

同一前缀还必须存在：

```text
jdcloud-re-ss-01-libwrt-<variant>-v<version>-initramfs-uImage.itb
jdcloud-re-ss-01-libwrt-<variant>-v<version>.manifest
```

每个 Release 还包含 `profiles.json`、`build.config`、`BUILD-METADATA.txt` 和 `SHA256SUMS`。发布前检查会拒绝空文件、其他设备或变体混入、factory 未按 65536 字节对齐、manifest 缺少必需包、元数据不一致或 SHA-256 覆盖不完整。

## Latest 与 Prerelease

- Argon 稳定版是正式 Release；通过发布检查后可以标记为 GitHub Latest。当前稳定线版本为 `1.0.0`。
- iStoreOS Dashboard beta 永远是 Prerelease，且必须显式设置为非 Latest。当前测试线版本为 `0.1.0-beta.9`。
- iStore 云编译成功不会改变其 beta 状态。完成 RE-SS-01 真机物理验收并进入后续稳定发布决策前，Argon 仍是稳定推荐。

`re-ss-01-istore-v0.1.0-beta.1` 保留用于问题追踪，但因真机出现重启后基础网络失效，不再推荐下载或刷写；不要删除、覆盖或重新使用该标签。

`re-ss-01-istore-v0.1.0-beta.4` 是 beta.5 的前一版，保留其 Release 用于回溯；`re-ss-01-istore-v0.1.0-beta.2` 仍保留为更早的历史 Release 及以下文件名。beta.3 构建未生成 Release。beta.4 使用 Xray 26.3.27，不能用于验证 tunnel UDP 修复：

```text
jdcloud-re-ss-01-libwrt-istore-v0.1.0-beta.2-squashfs-factory.bin
jdcloud-re-ss-01-libwrt-istore-v0.1.0-beta.2-squashfs-sysupgrade.bin
```

Release 说明应记录设备、变体、产品版本、`LiBwrt/LibWrt:25.12-nss` 源码提交、构建仓库提交和配置路径。下载后必须根据同一 Release 的 `SHA256SUMS` 校验，不能只看文件名刷写。
