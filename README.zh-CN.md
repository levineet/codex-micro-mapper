<img src="docs/images/app-icon.png" width="80" alt="Codex Micro Mapper 图标">

# Codex Micro Mapper

简体中文 · [English](README.md)

一个原生 macOS 菜单栏应用，将 **Work Louder Codex Micro** 的按键映射为快捷键和应用操作。

macOS 14+ · Swift 6.2+ · 本地处理 · 无使用数据统计

## 它解决什么问题

宏键盘的按键，应该用来完成你每天真正需要的操作。Codex Micro Mapper 让你为每个按键设置快捷键、打开应用、切到前台、在前台时隐藏，或在应用激活后追加快捷键。所有配置都在一个简洁的原生设置窗口中完成。

程序响应设备的 ACT06–ACT12 硬件标识，不修改键盘固件，也不改写其他应用的内部快捷键。这是一个独立的社区项目，与 Work Louder 或 OpenAI 没有官方隶属关系。

![按键映射界面](docs/images/mappings-zh.jpg)

## 主要功能

- 录制快捷键，或手动选择单个按键，支持 Home、**左/右 Option** 等。
- 打开应用或切到前台，再次按下时选择隐藏或保持显示。
- 确认应用已在前台后，再发送追加快捷键。
- 单独启用、停用映射，或清空全部六个按键。
- 简体中文和英文界面，可选择登录时启动。

底部宽键的 ACT10 和 ACT11 两个开关会合并为一个按键。ACT12 保留针对设备 `:yolo:` 占位文本的验证：只有精确匹配才删除，输入焦点变化时取消操作。

## 关于隐私

**本应用不会在后台记录日常打字内容，没有统计 SDK、遥测上传或后台服务连接，也不会建立日常打字内容历史。**

需要明确说明两种主动操作：

1. 点击“录制快捷键”时，程序会临时监听当前 macOS 会话的按键代码和修饰键，并拦截录制中的事件，以减少与其他全局快捷键的冲突。完成或取消后结束；清理时可能短暂等待已经按住的键松开。
2. 使用 ACT12 的验证快捷键时，程序通过辅助功能读取当前焦点和选中文本，确认是否精确等于 `:yolo:`。这些文字不会写入映射配置或诊断记录。

正常运行时，映射监听匹配的 Codex Micro 设备报告。应用将配置和偏好保存在本机，不会上传；诊断记录只在内存中保留，点击“复制”才会写入剪贴板。macOS 授予的系统权限范围，比本应用的具体用途更广；权限名称本身不能证明一个应用如何使用它。

完整的数据范围及对应源码见 [隐私说明](PRIVACY.zh-CN.md)。映射调用的其他应用、网址或 macOS 快捷指令，可能有各自的联网行为和隐私政策。

## 开始使用

### 运行条件

- macOS 14 或更新版本，以及 Work Louder Codex Micro。
- 已安装 Codex，用于配置设备中的按键布局。
- 为本应用开启输入监控和辅助功能权限。
- 从源码构建需要 Xcode 26，以及 Swift 6.2 或更新版本。

首个可下载构建面向 **Apple Silicon（arm64）**，使用本地签名，尚未使用 Developer ID 签名或经过 Apple 公证。不将 Intel 安装包或未实测的硬件行为宣称为已验证；你也可以检查源码后自行构建。

### 先设置设备按键

在 Codex 的 **设置 → Codex Micro → 布局** 中，按下表设置：

| 实体位置 | Codex 中的设置 | 硬件标识 |
| --- | --- | --- |
| 下排从左起第 1 键 | Empty 1 | ACT06 |
| 下排第 2 键 | Empty 2 | ACT07 |
| 下排第 3 键 | Empty 3 | ACT08 |
| 下排第 4 键 | Empty 4 | ACT09 |
| 底部宽键 | Empty 5 | ACT10 + ACT11 |
| 底部右键 | Yolo | ACT12 |

打开 Mapper，按提示开启权限，然后在“按键映射”中点击要设置的按键。如果旧版 `Codex Micro Mapping.app` 正在运行，请先退出它，避免两个助手同时监听。Mapper 会识别冲突并等待你处理。

### 首次启动的示例

首次启动包含 Command-N、Codex、ChatGPT、Chrome、Home 和验证后回车六个示例。它们都可以修改，不是必须使用的应用。点击 **通用 → 清空按键设置**，即可让六个按键都变为“未设置”。升级会保留现有配置。

### 从源码构建并安装

```bash
git clone https://github.com/levineet/codex-micro-mapper.git
cd codex-micro-mapper
swift test --disable-sandbox
bash scripts/build-app.sh
bash scripts/install-app.sh
```

构建产物为 `outputs/Codex Micro Mapper.zip`。安装前请先退出 Mapper。安装脚本替换 `/Applications/Codex Micro Mapper.app`，并保留映射文件和安装包的签名。项目不依赖第三方 Swift 包。

下载安装包时，请使用本仓库的 [Releases](https://github.com/levineet/codex-micro-mapper/releases)，并核对 SHA-256 校验和。签名限制和发布步骤见 [发布说明](docs/RELEASING.md)。

## 常见问题

| 情况 | 检查项 |
| --- | --- |
| 按键没有反应 | 设备连接、Codex 中的按键布局、输入监控权限，以及映射开关 |
| 无法录制或发送快捷键 | 辅助功能及输入权限；也可以使用手动选键菜单 |
| 已开启权限，仍显示需要权限 | 遵循 macOS 自身提示；部分权限变更或重新签名需要退出再打开，或重新授权 |
| 目标应用不响应快捷键 | 检查目标应用的快捷键设置，以及它是否支持全局唤起 |
| 提示旧版助手冲突 | 退出 `Codex Micro Mapping.app`，冲突解除后会恢复监听 |
| ACT12 没有清理占位文本 | 无法验证精确匹配时会保留文本；焦点变化时取消操作 |

## 代码结构

| 目录 | 职责 |
| --- | --- |
| `Sources/CodexMicroCore` | 映射模型、HID 解码、按下去重、快捷键捕获和安全判断 |
| `Sources/CodexMicroSystem` | HID、权限检查、临时录制和动作执行 |
| `Sources/CodexMicroMapperApp` | SwiftUI 界面、生命周期和本地存储 |
| `Tests` | 核心逻辑、系统决策和配置持久化测试 |

单元测试与 CI 不会授予系统权限，也不能代替真实 Codex Micro 的实体按键测试。参与方式与验证要求见 [贡献指南](CONTRIBUTING.md)。

## 许可证与致谢

作者 **Steve**。项目采用 [MIT 许可证](LICENSE)：允许使用、修改、分发和商业使用，需保留版权和许可证声明。

文中产品名称及第三方应用图标归各自权利人所有。应用图标由系统从已安装的应用中读取，并非作为可复用素材捆绑提供。详见 [第三方说明](THIRD_PARTY_NOTICES.md)。
