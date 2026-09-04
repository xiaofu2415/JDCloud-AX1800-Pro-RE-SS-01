# JDCloud RE-SS-01 OpenWrt 云编译

这个仓库只负责通过 GitHub Actions 编译京东云无线宝 AX1800 Pro（机身型号 `RE-SS-01`）固件。

## 编译来源

- 源码：[LiBwrt/LibWrt](https://github.com/LiBwrt/LibWrt)
- 分支：`25.12-nss`
- 平台：`qualcommax/ipq60xx`
- 设备：`jdcloud_re-ss-01`
- 内核系列：Linux 6.12

每次运行都会浅克隆该分支的最新提交，实际源码提交号会写入 Release 说明。

## 开始编译

1. 打开仓库的 **Actions** 页面。
2. 如果 GitHub 提示工作流尚未启用，先点击启用按钮。
3. 在左侧选择 **Build JDCloud RE-SS-01**。
4. 点击 **Run workflow**，选择 `main` 后确认运行。
5. 等待构建完成，在 **Releases** 或该次运行的 **Artifacts** 下载结果。

无需设置个人访问令牌或仓库 Secret。workflow 使用当前仓库自动提供的 `GITHUB_TOKEN` 发布 Release。

## 文件选择

- 从原厂固件或不同分区布局首次刷入时，不要直接使用 `sysupgrade.bin`。
- `factory.bin` 与 `sysupgrade.bin` 的使用前提取决于当前 U-Boot 和分区布局。
- 刷写前必须备份设备特有分区并准备救砖方式；其他 IPQ60xx 机型的固件不能用于 `RE-SS-01`。

## 自定义软件包

基础差异配置位于 `configs/jdcloud-re-ss-01.config`。首次应先验证最小配置能稳定生成并启动固件，再逐项增加软件包。

## 本地检查

```bash
bash tests/test-builder.sh
```

该检查会确认 workflow 仅手动触发、上游与分支正确、Release 权限完整，并且配置只选择 `RE-SS-01`。
