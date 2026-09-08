import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CodexMicroCore

struct MappingEditorSheet: View {
    let binding: MappingBinding
    let language: AppLanguage
    let onSave: (MappingBinding) -> Bool
    let onRecordingChanged: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: EditorDraft
    @State private var isRecording = false
    @State private var saveFailed = false

    init(binding: MappingBinding, language: AppLanguage,
         onSave: @escaping (MappingBinding) -> Bool, onRecordingChanged: @escaping (Bool) -> Void) {
        self.binding = binding
        self.language = language
        self.onSave = onSave
        self.onRecordingChanged = onRecordingChanged
        let draft = EditorDraft(binding)
        _draft = State(initialValue: draft)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(ViewFormatting.physicalPosition(binding.control, language: language))
                        .font(SettingsMetrics.pageTitle)
                        .accessibilityAddTraits(.isHeader)
                    Text(ViewFormatting.controlTitle(binding.control))
                        .font(SettingsMetrics.secondaryFont).foregroundStyle(.secondary)
                }
                Spacer()
                KeyLocationIndicator(control: binding.control)
            }
            .padding(.horizontal, SettingsMetrics.pageInset)
            .frame(height: 80)

            SettingsDivider()
            HStack(spacing: 0) {
                SettingsSidebar(selection: kindSelection) {
                    Label(language.text("快捷键", "Shortcut"), systemImage: "keyboard")
                        .tag(EditorKind.shortcut)
                    Label(language.text("应用控制", "App Control"), systemImage: "macwindow")
                        .tag(EditorKind.application)
                }
                .scrollDisabled(true)
                .frame(width: SettingsMetrics.sidebarWidth)
                .disabled(isRecording)

                SettingsDivider()
                ScrollView {
                    VStack(alignment: .leading, spacing: SettingsMetrics.sectionSpacing) {
                        if draft.preservesLegacy { legacyConfiguration }
                        else { configuration }
                        if saveFailed {
                            Text(language.text("无法保存按键设置，请重试。", "Couldn’t save key mapping. Try again."))
                                .foregroundStyle(.red).font(SettingsMetrics.secondaryFont)
                        }
                    }
                    .padding(SettingsMetrics.pageInset)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .font(SettingsMetrics.bodyFont)
                .background(Color(nsColor: .windowBackgroundColor))
            }

            SettingsDivider()
            HStack(spacing: 8) {
                Toggle(language.text("启用按键", "Enable key"), isOn: $draft.isEnabled)
                    .toggleStyle(.switch).controlSize(.small)
                    .disabled(isRecording)
                Spacer()
                SettingsActionButton(language.text("取消", "Cancel"), role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                SettingsActionButton(language.text("保存", "Save"), prominent: true) {
                    guard let updated = draft.binding(for: binding) else { return }
                    if onSave(updated) { dismiss() } else { saveFailed = true }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isRecording || draft.binding(for: binding) == nil)
            }
            .padding(.horizontal, SettingsMetrics.pageInset)
            .frame(height: 60)
        }
        .font(SettingsMetrics.bodyFont)
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(width: 760, height: 520)
    }

    private var kindSelection: Binding<EditorKind?> {
        Binding(get: { draft.preservesLegacy ? nil : draft.kind }, set: { kind in
            guard let kind else { return }
            draft.kind = kind
            draft.preservesLegacy = false
        })
    }

    @ViewBuilder private var configuration: some View {
        switch draft.kind {
        case .shortcut:
            VStack(alignment: .leading, spacing: 8) {
                SettingsGroup {
                    ShortcutRecorder(shortcut: $draft.shortcut, language: language, onRecordingChanged: recordingChanged,
                                     title: language.text("按下时", "On press"))
                }
                if binding.control == .act12 {
                    Text(language.text(
                        "发送快捷键前，仅删除精确匹配的 :yolo:。输入焦点变化时取消。",
                        "Before sending the shortcut, only an exact :yolo: match is removed. Cancels if input focus changes."
                    ))
                    .font(SettingsMetrics.secondaryFont).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
                }
            }
        case .application:
            SettingsGroup {
                HStack(spacing: 12) {
                    Text(language.text("打开", "Open"))
                    Spacer(minLength: 12)
                    Button(action: chooseApplication) {
                        HStack(spacing: 6) {
                            if let app = draft.application {
                                ActionGlyph(action: .activateApplication(app, afterActivation: nil), size: 24)
                            }
                            Text(draft.application?.displayName ?? language.text("选择应用", "Choose App"))
                                .font(SettingsMetrics.bodyFont)
                                .lineLimit(1).truncationMode(.middle)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(SettingsMetrics.secondaryFont)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(language.text("选择应用", "Choose App"))
                    .accessibilityValue(draft.application?.displayName ?? language.text("未选择", "Not selected"))
                    .frame(maxWidth: 240, alignment: .trailing)
                }
                .accessibilityElement(children: .contain)
                .frame(minHeight: 44)

                if draft.application != nil {
                    SettingsDivider()

                    HStack(spacing: 12) {
                        Text(language.text("已在前台时", "When in front"))
                        Spacer(minLength: 12)
                        Picker(language.text("已在前台时", "When in front"), selection: $draft.frontmostBehavior) {
                            Text(language.text("选择操作", "Choose Action")).tag(nil as EditorFrontmostBehavior?)
                            Text(language.text("保持显示", "Keep Visible")).tag(EditorFrontmostBehavior.keepVisible as EditorFrontmostBehavior?)
                            Text(language.text("隐藏应用", "Hide App")).tag(EditorFrontmostBehavior.hide as EditorFrontmostBehavior?)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.regular)
                        .font(SettingsMetrics.bodyFont)
                        .fixedSize()
                    }
                    .frame(minHeight: 44)
                }
            }
            .disabled(isRecording)

            if draft.application != nil {
                SettingsGroup {
                    Toggle(language.text("切到前台后发送快捷键", "Send shortcut after activation"), isOn: $draft.sendsFollowUp)
                        .toggleStyle(SettingsRowToggleStyle())
                        .frame(minHeight: 44)
                        .disabled(isRecording)
                    if draft.sendsFollowUp {
                        SettingsDivider()
                        ShortcutRecorder(shortcut: $draft.followUp, language: language, onRecordingChanged: recordingChanged,
                                         title: language.text("发送", "Send"))
                    }
                }
            }
        }
    }

    private var legacyConfiguration: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsGroup(title: language.text("现有设置", "Current Settings")) {
                Text(binding.unrecognizedAction != nil
                    ? language.text("此版本无法执行这项动作。", "This action is not supported in this version.")
                    : ViewFormatting.actionDetail(binding.action, language: language))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 10)
            }
            Text(language.text("选择快捷键或应用控制来替换。", "Choose Shortcut or App Control to replace this action."))
                .font(SettingsMetrics.secondaryFont).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func recordingChanged(_ active: Bool) {
        isRecording = active
        onRecordingChanged(active)
    }

    private func chooseApplication() {
        let panel = NSOpenPanel()
        panel.title = language.text("选择应用", "Choose App")
        panel.prompt = language.text("选择", "Choose")
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url, let bundle = Bundle(url: url),
              let identifier = bundle.bundleIdentifier else { return }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        let app = ApplicationTarget(bundleIdentifier: identifier, displayName: name)
        draft.application = app
    }
}
