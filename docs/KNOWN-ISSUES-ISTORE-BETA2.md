# iStoreOS Dashboard beta.2 已知问题

本文记录 `re-ss-01-istore-v0.1.0-beta.2` 在京东云 AX1800 PRO（`RE-SS-01`）上的真机验收结果。状态分为“已确认”“待终端确认”“环境相关”和“符合设计”，避免把未验证的推测写成固件缺陷。

## 已确认问题

| 优先级 | 问题 | 证据 | 影响 |
| --- | --- | --- | --- |
| P1 | PassWall2 首次启动存在运行目录初始化竞态 | beta.2 早期 04:50–04:59 日志曾报告 `/tmp/etc/passwall2/bin/xray` 没有执行权限；当前 `/usr/bin/xray`、临时链接和 `/tmp` 挂载均正常，手动启动后 Core、Xray[2001]、DNS[2002]、Dnsmasq[2004] 均运行，未出现新的权限错误 | 仅可能影响启动过早或运行目录尚未准备好的节点测试；旧日志会继续保留 |
| P0 | 运行时 APK 软件源包含 9 个无效仓库 | `apk update` 的核心源和 iStore compat 源成功，但 `istore`、`mosdns`、`nas`、`nas_luci`、`nss_packages`、`passwall2`、`passwall_packages`、`sqm_scripts_nss`、`video` 被错误指向 `mirrors.vsean.net/openwrt/releases/...`，返回下载错误；最终退出码为 9 | QuickStart 显示“软件源错误”，第三方包无法正常更新 |
| P1 | Samba 管理组件缺失 | `/admin/services/samba4` 返回 404；当前配置和必需包校验均未包含 `luci-app-samba4` | 无法从 LuCI 配置 Samba，与完整版目标不符 |
| P1 | ttyd 在 LAN 重载后曾无法访问 | `ttyd` 进程仍存在且绑定 `@lan`/`br-lan`，但 `192.168.100.1:7681` 曾拒绝连接；稍后重新连接恢复并出现登录提示 | Web 终端可用性不稳定，网络改址后可能失联 |
| P1 | QuickStart CPU 温度显示错误（beta.2–beta.8，beta.9 已修复） | 历史版本 QuickStart 显示 `0℃`，标准 LuCI 同时读取到 CPU `67.7℃`、Wi-Fi `56℃/58℃` | 历史版本首页监控数据误导 |
| P1 | QuickStart 磁盘容量口径错误 | QuickStart 把约 7 GiB 的整个 `mmcblk0` 显示为系统根目录；实际可写 `/overlay` 只有约 1.89 GiB | 用户可能误判可写空间并把 Docker 数据写满 overlay |
| P1 | SQM 默认接口无效 | SQM 默认实例指向不存在的 `eth1`；真实 WAN 设备为 `wan` | 若直接启用，整形不会按预期工作 |
| P2 | eMMC 数据分区与 swap 未投入使用 | `/overlay` 正常，但约 3.98 GiB 的 `storage` 和约 512 MiB 的 swap 未挂载/未启用 | Docker、Samba 可用空间不足；内存压力时没有交换空间兜底 |

## beta.8 PassWall2 修复记录

beta.8 进一步修复了 PassWall2 全局开关与 init 启动项状态脱节的问题：首次启动和全局开关为 `0` 时核心仍不运行，但 init 服务保持启用；用户在 LuCI 打开主开关并保存后，不需要再到系统启动项页面手动启用。回归测试覆盖默认关闭、不误启动以及启用后的自动启动。

## beta.9 QuickStart 温度修复记录

beta.9 新增 `/usr/libexec/re-ss-01-cpu-temperature`，按 `cpu-thermal` 优先级读取 Qualcomm thermal zone，并通过受 LuCI 登录保护的 `/cgi-bin/luci/admin/status/re_ss_01_cpu_temperature` 返回 `cpuTemperature`。QuickStart 前端适配器只在 `/system/status/` 或 `/system/cpu/temperature/` 缺少有效温度时合并该值；上游已有有效值时保持原响应不变。当前路由器现场的标准 LuCI 读数为 65.7℃，应不再显示 0℃。

## beta.7 PassWall2 修复记录

beta.7 已把本次真机复现的占位节点问题固化到构建源码中：

- 当 `passwall2.rulenode.default_node` 为 `examplenode`（或其他已知占位值）且只存在一个真实节点时，启动同步会写入该节点；没有真实节点或存在多个真实节点时不会猜选，并通过系统日志提示用户明确选择。
- 同步服务启动顺序调整为早于 stock PassWall2 服务，并同时检查 `pidof xray` 与活动 ACL 文件，避免仅凭 init 状态误报 Core 运行中。
- 当前现场已验证 `DirectFront`、`DirectGame` 为 `_direct`，活动配置为 `default:Reality`，Core 运行中；百度、Google、GitHub 测试分别返回约 1550、939、982 ms。旧的权限错误只保留在历史日志中，不能代表当前失败。
- beta.7 两个变体均不再打包 Docker/Dockerman，QuickStart 也不再声明 Docker 能力；`storage` 分区仍不自动格式化或挂载，Samba 数据目录须在分区核验后另行配置。
- beta.7 对 `luci-mod-status` 的信道分析图表加入隐藏标签延迟初始化，避免 2.4 GHz/5 GHz 图表在 `display:none` 时以零宽度生成重叠标签。

beta.7 仍需在刷入后完成 Reality 与 Hysteria2 各至少 30 分钟无 OOM、节点切换、重启和断电重启验收；云端构建成功本身不等于这些真机门槛已通过。

## 已取证但仍需在 beta.3 回归

### PassWall2 当前状态与修复边界

启动项页面显示 `passwall2：已禁用`，这是既定策略，不是故障。手动启动一次后页面显示 Core 运行中，日志出现 `Xray[2001]`、`DNS[2002]`、`Dnsmasq[2004]`，没有新增“没有执行权限”错误。旧的 04:50–04:59 记录会保留在日志中，不能作为当前状态判断。

root 终端已确认 `/usr/bin/xray` 和 `/tmp/etc/passwall2/bin/xray` 都可执行，临时链接指向 `/usr/bin/xray`，`/tmp` 没有 `noexec`，两个路径都能执行 `xray version`。因此 beta.3 不把 PassWall2 改成默认自启，而是在启动调用内确保运行目录存在并用可替换链接，回归时验证 Reality 与 Hysteria2 均能启动。

用于后续回归的只读检查为：

```sh
ls -l /usr/bin/xray /tmp/etc/passwall2/bin/xray
readlink -f /tmp/etc/passwall2/bin/xray
test -x /usr/bin/xray && echo usr-executable || echo usr-not-executable
test -x /tmp/etc/passwall2/bin/xray && echo tmp-executable || echo tmp-not-executable
mount | grep -E ' on /tmp | on / '
/usr/bin/xray version
/tmp/etc/passwall2/bin/xray version
```

这些命令只用于回归取证；不应通过 `chmod`、重装核心或取消 `/tmp` 的安全挂载属性来掩盖问题。

### LAN 重载

系统日志曾记录 5 次完整 LAN 重载，但时间集中在修改 LAN 地址和应用网络配置期间。之后超过 10 分钟未观察到新的自动重载。当前只能判定为“配置应用期间发生”，不能判定为随机掉网。需要在无任何保存操作时连续观察，并用日志时间戳区分人工应用与后台触发。

## 环境相关，不直接判为固件缺陷

- 当前 WAN 已获得 IPv4、IPv6 地址和默认路由；IPv4 上网、DNS、Wi-Fi 和 DHCP 正常。
- WAN6 获得公网 IPv6，但 LAN 没有公共前缀、没有 DHCPv6 租约，`odhcpd` 因此不向 LAN 宣告默认路由。上级路由器可能只提供 IPv6 地址而没有提供 Prefix Delegation；需先确认上级 PD 后再判断固件。
- 原先 LAN 与上级 WAN 同为 `192.168.1.0/24`，造成路由冲突；改为 `192.168.100.0/24` 后网络恢复。下一版不得未经用户选择自动改 LAN 地址，应提供冲突检测和明确提示。

## 符合设计或目前无故障证据

- 物理内存为 512 MiB、内核可管理约 405 MiB，其余由固件、NSS 和硬件预留；这不是内存丢失。
- 检查时可用内存约 178 MiB、负载约 `0.03`，没有出现 OOM 或持续高负载。
- PassWall2、MosDNS、AdGuard Home、Docker、Tailscale、Samba 和 SQM 默认关闭是既定安全策略；PassWall2 未设置开机自启不属于缺陷。
- Docker 未运行时 Dockerman 报无法连接 `/var/run/docker.sock` 属于预期状态。
- `ath11k` 的 `Not supported (-95)`、早期 `fstab: Entry not found`、部分 hostapd 清理警告尚未造成 Wi-Fi、NSS 或 overlay 故障；保留为观察项，不作为 P0/P1 修复依据。
- 当前 iStore 版本是“LibWrt + QuickStart + iStore”的 Dashboard 变体，不是官方 iStoreOS 24.10 完整移植。标准 LuCI 页面仍由 Argon 渲染，Bootstrap 为恢复主题。
- Tailscale 二进制预装但没有 LuCI 管理页；当前需求只承诺预装和默认关闭，因此暂列为产品限制，不列为缺包故障。

## beta.3 发布门槛

下一版 `0.1.0-beta.3` 至少必须满足：

1. `apk update` 返回 0，且不存在上述 9 个失效地址。
2. PassWall2 默认仍关闭；手动启动后 Reality 与 Hysteria2 的节点测试可以启动 Xray，Core 状态与进程状态一致，且不产生新的权限错误。
3. Samba LuCI 页面存在，服务默认关闭，且未配置共享时不开放端口。
4. 修改或重载 LAN 后，ttyd 能在 10 秒内重新连接，且 WAN 侧无法访问。
5. SQM 默认保持关闭，预设接口为 `wan`。
6. 首页不再把 `0℃` 当作有效 CPU 温度，也不再把整块 eMMC 当作可写根目录。
7. 不自动格式化、挂载未知数据分区，不自动启用 swap；所有存储变更必须经过真机分区确认。
8. WAN、LAN、DHCP、DNS、2.4/5 GHz Wi-Fi、NSS、重启和断电重启回归通过。
