import SwiftUI
import CodexMicroCore
import CodexMicroSystem

struct ShortcutRecorder: View {
    @Binding var shortcut: KeyStrokeDefinition?
    let language: AppLanguage
    let onRecordingChanged: (Bool) -> Void
    var title: String? = nil
    @StateObject private var recorder = ShortcutRecordingService()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(title ?? language.text("快捷键", "Shortcut"))
                    .font(SettingsMetrics.bodyFont)
                Spacer(minLength: 12)
                HStack(spacing: 0) {
                    Button {
                        connect()
                        recorder.start()
                    } label: {
                        Text(displayText)
                            .font(SettingsMetrics.bodyFont.weight(shortcut == nil ? .regular : .medium))
                            .foregroundStyle(shortcut == nil && !recorder.isRecording ? .secondary : .primary)
                            .lineLimit(1).minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, minHeight: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(recorder.isRecording)
                    .accessibilityLabel(language.text("录制快捷键", "Record Shortcut"))
                    .accessibilityValue((recorder.isRecording ? recorder.preview : shortcut).map {
                        ViewFormatting.shortcutAccessibilityText($0, language: language)
                    } ?? displayText)
                    .help(language.text("按下并松开要录制的快捷键", "Press and release the shortcut to record"))

                    SettingsDivider().frame(height: 14)
                    Menu {
                        ShortcutKeyMenu(language: language, canClear: shortcut != nil,
                                        onSelect: selectManually,
                                        onClear: { recorder.cancel(); shortcut = nil })
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .disabled(recorder.isRecording)
                    .accessibilityLabel(language.text("快捷键选项", "Shortcut Options"))
                    .help(language.text("选择单个按键或清除快捷键", "Choose a single key or clear the shortcut"))
                }
                .frame(width: 196)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(recorder.isRecording ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: recorder.isRecording ? 1.5 : 0.75)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityElement(children: .contain)
            if !statusText.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(statusText).font(SettingsMetrics.secondaryFont).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if recorder.isRecording {
                        Button(language.text("取消", "Cancel")) { recorder.cancel() }
                            .buttonStyle(.link).font(SettingsMetrics.secondaryFont)
                    }
                    if case .failed(.permissions) = recorder.state {
                        Menu(language.text("设置", "Settings")) {
                            Button(language.text("输入监控", "Input Monitoring")) {
                                PermissionService().openSystemSettings(.inputMonitoring)
                            }
                            Button(language.text("辅助功能", "Accessibility")) {
                                PermissionService().openSystemSettings(.accessibility)
                            }
                        }
                        .fixedSize()
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .padding(.vertical, 8)
        .onAppear { connect() }
        .onDisappear { recorder.cancel() }
    }

    private var displayText: String {
        if recorder.isRecording {
            if let preview = recorder.preview { return ViewFormatting.shortcutText(preview, language: language) }
            return language.text("按下快捷键", "Press Shortcut")
        }
        return shortcut.map { ViewFormatting.shortcutText($0, language: language) }
            ?? language.text("录制快捷键", "Record Shortcut")
    }

    private var statusText: String {
        switch recorder.state {
        case .idle: ""
        case .recording: language.text("松开全部按键完成录制，按 Esc 取消。", "Release all keys to finish. Press Esc to cancel.")
        case .waitingForRelease: language.text("先松开已按住的按键。", "Release held keys first.")
        case .releasing: language.text("松开按键结束录制。", "Release all keys to finish.")
        case .failed(.permissions): language.text("开启输入监控和辅助功能以录制，或从菜单选择按键。", "Enable Input Monitoring and Accessibility to record, or choose a key from the menu.")
        case .failed(.unavailable): language.text("无法录制。检查权限，或从菜单选择按键。", "Can’t record. Check permissions or choose a key from the menu.")
        case .failed(.interrupted): language.text("录制中断，原快捷键未更改。", "Recording interrupted. Your shortcut is unchanged.")
        case .failed(.busy): language.text("先结束另一处快捷键录制。", "Finish the other shortcut recording first.")
        }
    }

    private func selectManually(_ key: KeyStrokeDefinition) {
        recorder.cancel()
        shortcut = key
    }

    private func connect() {
        recorder.onCapture = { shortcut = $0 }
        recorder.onSessionChanged = onRecordingChanged
    }
}
