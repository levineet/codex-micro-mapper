# 隐私说明

简体中文 · [English](PRIVACY.md)

本文说明本仓库 **1.8.1** 版本的实现，更新于 **2026 年 9 月 8 日**，不代表 macOS 或你通过映射调用的其他应用的行为。

## 本地处理

Codex Micro Mapper 无需账号。应用未实现统计、广告、遥测、崩溃上传或网络客户端，使用 Apple 系统框架，不依赖第三方 SDK。按键识别、映射查找和动作决策都在你的 Mac 上完成。见[项目依赖](Package.swift)。

发送给其他应用的操作仍可能产生网络活动。例如打开浏览器、启动录音应用或用快捷键提交文字，目标应用如何处理和发送数据，取决于它自己的行为及隐私政策。

## 应用会读取什么

**Codex Micro 事件。** 启用映射且输入监控权限可用时，硬件监听接收匹配厂商标识 `0x303A`、产品标识 `0x8360` 和报告标识 `6` 的设备报告，解析硬件按键标识及按下、松开事件。为兼容后续固件，这些厂商消息中的未知按键标识也会保留；这不是普通键盘的日常打字记录。设备名称、连接方式等连接信息保留在内存中。见 [HID 服务](Sources/CodexMicroSystem/CodexMicroHIDService.swift)和[解码器](Sources/CodexMicroCore/HIDFrameDecoder.swift)。

**快捷键录制。** 点击“录制快捷键”后，应用会临时建立覆盖当前 macOS 会话的键盘事件监听，也能接收到 Codex Micro 以外键盘的事件。它读取按键代码和修饰键状态，包括左右修饰键，并拦截录制中的事件，以减少与其他全局快捷键的冲突。保存的是一个快捷键定义，不是输入的句子或完整打字历史。

录制完成或取消后会移除监听。应用或录制窗口失去焦点、所需权限不可用时会中断录制。取消时可能继续保留监听最多两秒，以处理已拦截按键的松开事件；清理期间会放行无关的新输入。录制结果先保留为编辑草稿，点击“保存”后才写入配置。见[录制服务](Sources/CodexMicroSystem/ShortcutRecordingService.swift)、[快捷键捕获逻辑](Sources/CodexMicroCore/ShortcutCapture.swift)和[录制界面](Sources/CodexMicroMapperApp/Views/ShortcutRecorder.swift)。

**ACT12 选中文本。** ACT12 的验证动作通过辅助功能读取前台应用、输入焦点和当前选中文本，以检查 `:yolo:` 占位符。应用先向左选择文本，只有整段选中文本精确匹配占位符且焦点检查通过时，才会删除。目标应用提供的选区可能长于占位符，因此不能保证读取的内容恰好只有六个字符。焦点变化时会取消删除和最终快捷键。这段选中文本不会写入映射文件、诊断记录或上传。见[动作执行器](Sources/CodexMicroSystem/SystemActionExecutor.swift)和[安全判断](Sources/CodexMicroCore/SafetyDecisions.swift)。

**应用与键盘状态。** 应用控制会检查前台应用，以及目标应用是否正在运行或隐藏。旧版助手检查会读取正在运行的应用标识和路径，以识别冲突。选择应用时会读取它的 Bundle ID、名称和本地图标；发送快捷键前会检查修饰键是否按住及 Caps Lock 状态。这些检查不会建立持久的应用使用历史。见[动作执行器](Sources/CodexMicroSystem/SystemActionExecutor.swift)、[旧版助手检测](Sources/CodexMicroSystem/LegacyHelperMonitor.swift)和[应用选择器](Sources/CodexMicroMapperApp/Views/MappingEditorSheet.swift)。

本应用不采集麦克风音频或截屏，也不会在后台监视、读取剪贴板内容。

## 保存哪些数据

| 数据 | 位置与保留方式 |
| --- | --- |
| 按键映射 | `~/Library/Application Support/Codex Micro Mapper/mappings.json`，保留至替换或删除。包含按键代码、修饰键、动作开关、应用标识和名称、追加快捷键及旧版动作参数。无法识别的动作 JSON 也会保留。 |
| 语言与总映射开关 | 标识为 `local.codex.micro.mapper` 的 macOS 偏好设置，保留至修改或删除。 |
| 实例锁 | 同一 Application Support 目录下的 `instance.lock`，用于防止多个实例同时监听，应用不向其中写入数据内容。 |
| 登录时启动 | 开启后由 macOS `SMAppService` 管理注册。 |
| 诊断记录 | 当前运行会话的内存中最多保留 80 条；界面及复制内容包含最后 20 条和当前状态。未实现诊断文件保存或上传。 |

配置使用普通 JSON 和 macOS 偏好设置，没有应用层加密。macOS、备份或其他软件可能保留额外副本。见[映射存储](Sources/CodexMicroMapperApp/MappingStore.swift)、[应用状态](Sources/CodexMicroMapperApp/AppModel.swift)、[实例锁](Sources/CodexMicroSystem/SingleInstanceGuard.swift)和[登录启动服务](Sources/CodexMicroSystem/LaunchAtLoginService.swift)。

## 诊断与剪贴板

诊断包含连接和权限状态、硬件按键标识、本地时间及动作结果。错误信息可能包含应用名、macOS 快捷指令名称、文件名、路径或 URL 信息。诊断**不保证匿名**，分享前请检查内容。

点击诊断中的“复制”，会用诊断文字替换系统剪贴板内容，应用不会自动将其发送给任何人。macOS 或剪贴板管理工具可能保留、同步副本。系统原生的复制操作仍可使用；Command-C、Command-V 等映射也可能让目标应用访问剪贴板。见[诊断生成与复制](Sources/CodexMicroMapperApp/AppModel.swift)。

## 旧配置与其他应用

编辑器目前聚焦快捷键和应用控制，但已有配置仍可打开 URL、文件、文件夹，运行指定名称的 macOS 快捷指令，或发送 Typeless 录音快捷键。URL 和文件会交给系统指定的应用，快捷指令名称会交给 Shortcuts。Mapper 不读取所打开文件的内容，也不替 Typeless 采集音频；被调用的应用或快捷指令可能处理数据或联网。见[旧版动作模型](Sources/CodexMicroCore/MappingModels.swift)、[旧配置保留逻辑](Sources/CodexMicroMapperApp/EditorDraft.swift)和[动作执行器](Sources/CodexMicroSystem/SystemActionExecutor.swift)。

## 你可以如何控制

- **暂停映射**：停止常规硬件监听和映射动作。正在进行的快捷键录制请另外取消。
- **撤销权限**：前往 macOS **系统设置 → 隐私与安全性 → 输入监控 / 辅助功能**。应用会定期及回到前台时检查权限；输入监控不可用时停止硬件监听，辅助功能或事件发送权限不可用时阻止执行映射。部分权限变更可能需要按 macOS 提示退出并重新打开应用。撤销权限不会删除已保存的设置。
- **通用 → 清空按键设置**：将所有映射替换为六个未设置的按键。它不会重置语言、总开关、登录启动、系统授权、诊断记录或剪贴板副本，也不等于安全擦除数据。
- **退出应用**：停止应用的监听并结束内存中的诊断会话。如需删除本地映射文件，请先退出，再删除 `~/Library/Application Support/Codex Micro Mapper/`。偏好设置和系统授权需分别管理；删除文件无法移除备份或其他软件已有的副本。

这些说明对应当前源码实现，不代表经过独立隐私审计、网络抓包验证，也不保证第三方构建的行为。反馈问题时，请只分享复现所需的配置或诊断，并先移除个人信息。
