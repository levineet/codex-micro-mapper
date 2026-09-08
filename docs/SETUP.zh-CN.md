# 设置与常见问题

[返回 README](../README.zh-CN.md) · [English](SETUP.md)

## 运行条件

- macOS 14 或更新版本，以及 Work Louder Codex Micro。
- 已安装 Codex，用于配置设备按键布局。
- 为 Mapper 开启输入监控和辅助功能权限。
- 从源码构建需要 Xcode 26，以及 Swift 6.2 或更新版本。

可下载的安装包面向 **Apple silicon（arm64）**，使用临时签名，尚无 Developer ID 签名或 Apple 公证，暂不提供 Intel 安装包。签名详情见[发布说明](RELEASING.md)。

## 安装应用

从本仓库的 [Releases](https://github.com/levineet/codex-micro-mapper/releases) 下载 App ZIP，并对照 `SHA256SUMS.txt` 核对 SHA-256。GitHub 自动生成的 **Source code** 压缩包是源码，不是 App 安装包。

先退出正在运行的 Mapper，再解压 App ZIP，将 `Codex Micro Mapper.app` 移入“应用程序”。如果 macOS 阻止打开，请遵循系统安全提示，或检查源码后自行构建；不要关闭系统安全保护。

如果旧版 `Codex Micro Mapping.app` 正在运行，请先退出它。两个助手不能同时监听键盘；Mapper 会识别冲突，等待你退出旧助手。

## 设置 Layer 1 按键

在 Codex 中打开 **设置 → Codex Micro → 布局**，将 **第一层（Layer 1）下方两排**按下表设置：

| 实体位置 | Codex 中的设置 | 硬件标识 |
| --- | --- | --- |
| 下排从左起第 1 键 | Empty 1 | ACT06 |
| 下排第 2 键 | Empty 2 | ACT07 |
| 下排第 3 键 | Empty 3 | ACT08 |
| 下排第 4 键 | Empty 4 | ACT09 |
| 底部宽键 | Empty 5 | ACT10 + ACT11 |
| 底部右键 | Yolo | ACT12 |

程序识别 ACT 硬件标识，不依赖按键上的文字。ACT10 和 ACT11 是宽键下方的两个开关，会合并为一个逻辑按键。

## 开启权限并选择操作

打开 Mapper，按提示开启权限。两项权限均位于 **系统设置 → 隐私与安全性**：

| 权限 | 用途 |
| --- | --- |
| 输入监控 | 接收 Codex Micro 的按键报告。 |
| 辅助功能 | 发送快捷键、控制应用，以及验证 ACT12 的选中文本。 |

在“按键映射”中开启映射，点击按键即可编辑。每个按键都可以独立选择快捷键或应用控制，在同一布局中混用。快捷键支持录制，也可从菜单选择 Home、**左/右 Option** 等单个按键；应用控制可指定目标应用、已在前台时的操作，以及激活后追加的快捷键。

关闭设置窗口后，Mapper 仍在菜单栏运行。映射配置保存在本机，输入读取范围见[隐私说明](../PRIVACY.zh-CN.md)。

### 首次启动的示例

首次启动包含 Command-N、Codex、ChatGPT、Chrome、Home 和验证后回车六个示例，均可修改，不是必须使用的应用。点击 **通用 → 清空按键设置** 并确认，即可让六个按键变为“未设置”。升级会保留已有配置。

### ACT12 与 `:yolo:`

请在 Codex 中将 ACT12 保持为 **Yolo**。为 ACT12 配置快捷键后，Mapper 会等待设备输入占位文本，再检查前台应用、输入焦点和选中文本。只有精确匹配 `:yolo:` 才会删除，随后发送已配置的快捷键，默认为回车。

无法验证匹配时会保留文字；前台应用或输入焦点变化时，同时取消清理和快捷键发送。清空 ACT12 的映射只会停用 Mapper 的操作，不会更改设备自身的 Yolo 设置。

## 从源码构建

项目不依赖第三方 Swift 包。运行安装脚本前，请先退出 Mapper。

```bash
git clone https://github.com/levineet/codex-micro-mapper.git
cd codex-micro-mapper
swift test --disable-sandbox
bash scripts/build-app.sh
bash scripts/install-app.sh
```

构建产物为 `outputs/Codex Micro Mapper.zip`。安装脚本替换 `/Applications/Codex Micro Mapper.app`，同时保留安装包的签名和已有映射文件。签名变更可能需要重新授权系统权限。

单元测试和 CI 不会授予 macOS 权限，也不能模拟实体按键。验证要求见[贡献指南](../CONTRIBUTING.md)，签名和发布步骤见[发布说明](RELEASING.md)。

## 常见问题

| 情况 | 检查项 |
| --- | --- |
| 按键没有反应 | 设备连接、Codex 的 Layer 1 设置、输入监控权限，以及总开关和单个按键开关。 |
| 无法录制或发送快捷键 | 检查辅助功能和输入权限，也可使用手动选键菜单。 |
| 已开启权限，仍显示需要权限 | 遵循 macOS 提示；部分权限或签名变更需要退出再打开 Mapper，或重新授权。 |
| 目标应用不响应快捷键 | 检查该应用的快捷键设置和全局快捷键支持情况。生成的 Home 或右 Option 事件仍需目标应用支持。 |
| 提示旧版助手冲突 | 退出 `Codex Micro Mapping.app`；冲突解除且其他运行条件满足后，会恢复监听。 |
| ACT12 没有清理 `:yolo:` | 无法验证或选中文本不匹配时会保留文字；前台应用或输入焦点变化时取消操作。 |
