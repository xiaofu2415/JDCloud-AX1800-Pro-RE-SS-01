# 存储、Docker 与 swap 策略

RE-SS-01 的 eMMC 约 6.96 GiB。系统可写层 `/overlay` 约 1.89 GiB；另有约 3.98 GiB 的 `storage` 分区和约 512 MiB 的 `swap` 分区。它们不是“看见分区就可以直接使用”的临时目录，必须先确认身份和数据归属。

## 核验顺序

在标准 LuCI 的“系统 → 挂载点”或 root 终端中只读确认：

```sh
blkid
ls -l /dev/mmcblk0*
cat /etc/config/fstab
mount
```

记录每个分区的 UUID、文件系统类型、标签和当前挂载点。没有确认 UUID 与文件系统类型前，不执行 `mkfs`、`dd`、分区调整或覆盖写入。

## storage 分区

只有确认分区中没有需要保留的数据后，才允许创建挂载点并通过 LuCI 配置 UUID 挂载到 `/mnt/storage`。挂载后再分别创建：

```text
/mnt/storage/docker   Docker 数据根目录
/mnt/storage/share    Samba 共享目录
```

Docker 和 Samba 默认关闭。启用任一服务前，先确认该挂载在重启后稳定出现，并检查剩余空间、目录属主和权限。不要把 Docker 数据目录放回小容量 `/overlay`。

## swap 分区

约 512 MiB 的分区默认保持关闭。只有确认它确实是 swap 分区、没有用户数据且不会与系统升级布局冲突后，才可人工配置低优先级 swap。启用前后记录 `swapon --show` 和 `free -h`；固件不自动格式化、覆盖或启用未知分区。

## 回滚边界

挂载或启用 swap 后如果出现启动、Docker、Samba 或升级异常，先在 LuCI 中停用相关服务，再卸载对应分区并恢复原有 fstab。任何存储变更都应保留 U-Boot Web 或已验证的 factory 恢复路径。
