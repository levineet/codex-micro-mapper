# Contributing

English · [简体中文](#参与贡献)

Bug reports, small fixes, clearer wording and device test results are welcome. Check existing issues before starting a larger change. Please keep the app native, focused on shortcuts and app controls, and usable in both English and Simplified Chinese.

## Develop and check

Use macOS 14 or later, Xcode 26 and Swift 6.2 or newer. No third-party Swift packages are needed.

```bash
swift test --disable-sandbox
bash scripts/build-app.sh
```

Quit Mapper before running `bash scripts/install-app.sh`; it replaces the installed app while preserving mappings. A build with a different signature may require macOS permissions to be granted again. See [release instructions](docs/RELEASING.md).

For a pull request, explain the problem, the resulting behavior and what you verified. Include screenshots for visible changes. Keep tests focused on meaningful behavior; a UI spacing adjustment does not need a test that repeats its constants.

## Behavior to preserve

- ACT10 and ACT11 act as one key; reset held-key state on disconnect, reconnect and sleep/wake.
- Shortcut recording starts only on an explicit user action and ends on completion, cancellation or loss of focus. Keep event suppression and release cleanup bounded.
- ACT12 must check process, focus and the exact selected placeholder before deletion. Never replace this with unconditional backspaces. A focus change cancels both deletion and Return.
- Respect the single-instance guard and old-helper conflict handling. Do not force-quit another app.
- Preserve existing and unknown mapping data during compatibility changes. Update both privacy documents if data access, storage or network behavior changes.

## Report verification accurately

Unit tests cover decoding, reduction, capture and safety decisions, editor state and local storage. They do not prove that macOS grants permissions, that another app responds to a shortcut, or that a physical device works.

For hardware or permission changes, record the macOS/app version, device firmware when known, physical key positions, and observed result. Check reconnect/wake, duplicate presses, left/right modifiers, denied/revoked permissions and ACT12 focus changes as relevant. Mark untested cases explicitly.

Review diagnostics before posting: they may contain app names, paths or other personal details. Do not upload your full mapping file, signing keys or private information. Report vulnerabilities through [SECURITY.md](SECURITY.md).

## 参与贡献

欢迎反馈问题、提交小修复、改进文案或补充真实设备测试。较大的改动请先查看已有 Issue，再说明计划。界面保持原生、精简，并同步维护中英文。

使用 macOS 14+、Xcode 26 和 Swift 6.2+，运行上面的测试和构建命令。安装前先退出 Mapper；安装保留映射，签名变更可能需要重新授权系统权限。

提交时说明问题、修改后的行为和已完成的验证；界面修改附截图。保留双开关合并、按键状态重置、主动录制与及时清理、ACT12 精确匹配及焦点检查、单实例和旧助手冲突处理。不得无条件删除文字或强制退出其他应用。

单元测试不能替代硬件、系统权限或目标应用验证。相关改动请注明系统和应用版本、实体键位、观察结果与未测试项。分享诊断前删除私人信息，不上传个人映射文件或签名凭据。安全问题请按 [安全说明](SECURITY.md) 私下报告。
