import AppKit
import SwiftUI

struct GeneralView: View {
    @ObservedObject var model: AppModel

    @State private var confirmsClearMappings = false
    @State private var showsDiagnostics = false
    @State private var clearFailed = false

    var body: some View {
        SettingsPage(title: model.language.text("通用", "General")) {
            SettingsGroup(title: model.language.text("偏好设置", "Preferences")) {
                HStack(spacing: SettingsMetrics.rowSpacing) {
                    SettingsRowLabel(
                        systemName: "globe",
                        title: model.language.text("语言", "Language")
                    )

                    Spacer(minLength: 16)

                    Picker("", selection: languageBinding) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.regular)
                    .font(SettingsMetrics.bodyFont)
                    .fixedSize()
                }
                .padding(.vertical, SettingsMetrics.rowVerticalPadding)
                .settingsCellTrailingInset()

                SettingsDivider().padding(.leading, SettingsMetrics.rowTextInset)

                Toggle(isOn: launchAtLoginBinding) {
                    SettingsRowLabel(
                        systemName: "power",
                        title: model.language.text("登录时启动", "Launch at login")
                    )
                }
                .toggleStyle(SettingsRowToggleStyle())
                .padding(.vertical, SettingsMetrics.rowVerticalPadding)
                .settingsCellTrailingInset()
                .accessibilityHint(model.language.text(
                    "登录 Mac 后自动启动",
                    "Start automatically when you log in to your Mac"
                ))
            }

            SettingsGroup(title: model.language.text("系统权限", "System Permissions")) {
                SystemPermissionRow(
                    kind: .inputMonitoring,
                    state: PermissionUIState.resolve(model.permissions, kind: .inputMonitoring),
                    language: model.language,
                    openSettings: model.openInputMonitoringSettings
                )

                SettingsDivider().padding(.leading, SettingsMetrics.rowTextInset)

                SystemPermissionRow(
                    kind: .accessibility,
                    state: PermissionUIState.resolve(model.permissions, kind: .accessibility),
                    language: model.language,
                    openSettings: model.openAccessibilitySettings
                )
            }

            CodexKeySetupSection(model: model)

            SettingsGroup(title: model.language.text("映射与诊断", "Mappings and Diagnostics")) {
                HStack(spacing: SettingsMetrics.rowSpacing) {
                    SettingsRowIcon(systemName: "eraser")

                    Text(model.language.text("清空按键设置", "Clear key mappings"))
                        .font(SettingsMetrics.bodyFont)

                    Spacer(minLength: 12)

                    SettingsActionButton(model.language.text("清空", "Clear")) {
                        confirmsClearMappings = true
                    }
                }
                .padding(.vertical, SettingsMetrics.rowVerticalPadding)
                .settingsCellTrailingInset()
                if clearFailed {
                    Text(model.language.text("无法清空按键设置。原有设置已保留。", "Couldn’t clear key mappings. Your settings are unchanged."))
                        .font(SettingsMetrics.secondaryFont).foregroundStyle(.red)
                        .padding(.leading, SettingsMetrics.rowTextInset).padding(.bottom, 8)
                }
                SettingsDivider().padding(.leading, SettingsMetrics.rowTextInset)
                SettingsDisclosureRow(
                    systemName: "stethoscope",
                    title: model.language.text("诊断", "Diagnostics"),
                    language: model.language,
                    isExpanded: $showsDiagnostics
                )

                if showsDiagnostics {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.diagnosticsText.isEmpty
                            ? model.language.text("暂无诊断记录", "No diagnostics yet")
                            : model.diagnosticsText)
                            .font(SettingsMetrics.secondaryFont.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel(model.language.text("诊断信息", "Diagnostics"))

                        HStack {
                            Spacer()
                            SettingsActionButton(model.language.text("复制", "Copy")) {
                                model.copyDiagnostics()
                            }
                            .accessibilityLabel(model.language.text("复制诊断信息", "Copy Diagnostics"))
                        }
                        .settingsCellTrailingInset()
                    }
                    .padding(.leading, SettingsMetrics.rowTextInset)
                    .padding(.vertical, SettingsMetrics.rowVerticalPadding)
                }
            }

            SettingsGroup(title: model.language.text("关于", "About")) {
                HStack(alignment: .center, spacing: 16) {
                    MapperAppIcon(size: 64)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Codex Micro Mapper")
                            .font(SettingsMetrics.detailTitle)

                        Text(model.language.text("版本 \(versionText)", "Version \(versionText)"))
                            .font(SettingsMetrics.secondaryFont)
                            .foregroundStyle(.secondary)

                        Text(model.language.text(
                            "作者 \(authorText) · 更新于 \(releaseDateText)",
                            "By \(authorText) · Updated \(releaseDateText)"
                        ))
                        .font(SettingsMetrics.secondaryFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
                .settingsCellTrailingInset()
            }
        }
        .alert(
            model.language.text("清空所有按键设置？", "Clear All Key Mappings?"),
            isPresented: $confirmsClearMappings
        ) {
            Button(model.language.text("取消", "Cancel"), role: .cancel) {}
            Button(model.language.text("清空按键设置", "Clear Key Mappings"), role: .destructive) {
                clearFailed = !model.clearMappings()
            }
        } message: {
            Text(model.language.text(
                "六个按键将变为“未设置”，所有快捷键和应用操作都会移除。",
                "All six keys will become unassigned. Their shortcuts and app actions will be removed."
            ))
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(get: { model.language }, set: { model.setLanguage($0) })
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        )
    }

    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        guard let build, !build.isEmpty else { return version }
        return "\(version) (\(build))"
    }

    private var authorText: String {
        Bundle.main.object(forInfoDictionaryKey: "CodexMicroMapperAuthor") as? String ?? "Steve"
    }

    private var releaseDateText: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "CodexMicroMapperReleaseDate") as? String else { return "—" }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withFullDate]
        parser.timeZone = TimeZone(secondsFromGMT: 0)
        guard let date = parser.date(from: value) else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = model.language.locale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
