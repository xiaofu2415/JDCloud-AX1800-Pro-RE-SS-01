# 存储与 swap 策略

RE-SS-01 的 eMMC 约 6.96 GiB。系统可写层 `/overlay` 约 1.89 GiB；另有约 3.98 GiB 的 `storage` 分区和约 512 MiB 的 `swap` 分区。稳定候选固件只对已核验的设备身份声明挂载：`storage` 必须是 UUID `5d987db6-15b1-44db-9934-3bc086a4fd6e` 的 ext4，swap 必须是 `/dev/mmcblk0p26` 的已确认 swap 签名。固件不包含任何格式化或覆盖分区的命令。

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

稳定候选固件的 `/etc/config/fstab` 已写入上述 UUID，并以 `rw,noatime` 挂载到 `/mnt/storage`。UUID 或文件系统类型不匹配时，挂载会失败并保留分区原状；不会回退到按设备号盲挂载，也不会运行 `mkfs`。下一版固件不包含 Docker/Dockerman；若仅用于 Samba，可创建：

```text
/mnt/storage/share    Samba 共享目录
```

Samba 默认关闭。启用前，先确认该挂载在重启后稳定出现，并检查剩余空间、目录属主和权限。首次启动或升级后建议验证：

```sh
mountpoint -q /mnt/storage && df -h /mnt/storage
findmnt /mnt/storage
```

不要在未确认文件系统和数据归属时格式化或覆盖 `storage`。

## swap 分区

已核验的 `/dev/mmcblk0p26` 以优先级 `10` 启用；`auto_swap` 保持关闭，因此其他未知分区不会被扫描或启用。验证命令：

```sh
swapon --show
free -h
```

如果设备上的 p26 没有 swap 签名，启动脚本会跳过它，不会格式化或写入该分区。

## 回滚边界

挂载或启用 swap 后如果出现启动、Samba 或升级异常，先在 LuCI 中停用相关服务，再卸载对应分区并移除对应 fstab 条目。任何存储变更都应保留 U-Boot Web 或已验证的 factory 恢复路径。稳定候选验收仍要记录重启后 `findmnt /mnt/storage`、`swapon --show` 和可写测试结果。
