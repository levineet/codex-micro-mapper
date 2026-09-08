import CodexMicroCore
import SwiftUI

struct DeviceStatusLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Group {
            if !model.permissions.canListenToDevice || !model.permissions.canExecuteMappings {
                PermissionStatusLabel(state: .denied, language: model.language)
            } else {
                SettingsStatusLabel(title: title, systemName: symbol, color: color)
            }
        }
        .font(SettingsMetrics.secondaryFont)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        if model.legacyHelperRunning { return model.language.text("旧版助手占用中", "Legacy helper running") }
        if !model.isEnabled { return model.language.text("映射已暂停", "Mappings paused") }
        return model.isDeviceConnected ? model.language.text("已连接", "Connected") : model.language.text("未连接", "Not connected")
    }

    private var symbol: String {
        if model.legacyHelperRunning { return "exclamationmark.triangle.fill" }
        return model.isDeviceConnected && model.isEnabled ? "checkmark.circle.fill" : "circle.dotted"
    }

    private var color: Color {
        if model.legacyHelperRunning { return .orange }
        return model.isDeviceConnected && model.isEnabled ? .green : .secondary
    }
}

struct CodexKeySetupSection: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsGroup(title: model.language.text("Codex 按键设置", "Codex Key Setup")) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.language.text(
                            "在 Codex 中按下图设置按键。",
                            "Match these key settings in Codex."
                        ))
                        .font(SettingsMetrics.bodyFont)

                        Text(model.language.text("设置 → Codex Micro → 布局", "Settings → Codex Micro → Layout"))
                            .font(SettingsMetrics.secondaryFont)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    SettingsActionButton(model.language.text("打开 Codex", "Open Codex")) { model.openCodex() }
                        .fixedSize()
                }

                CodexSetupDiagram(language: model.language)
            }
            .padding(.vertical, 12)
        }
    }
}

struct LegacyHelperWarning: View {
    @ObservedObject var model: AppModel
    let stopLegacyHelper: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 15))
                .frame(width: SettingsMetrics.rowIconSize, height: SettingsMetrics.rowIconSize)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.language.text("旧版助手正在占用键盘", "Keyboard in Use by Legacy Helper"))
                    .fontWeight(.medium)
                Text(model.language.text(
                    "退出 Codex Micro Mapping 以启用按键映射。",
                    "Quit Codex Micro Mapping to enable key mappings."
                ))
                    .font(SettingsMetrics.secondaryFont)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            SettingsActionButton(model.language.text("退出旧版助手", "Quit Legacy Helper"), role: .destructive) {
                stopLegacyHelper()
            }
        }
        .padding(.vertical, 3)
        .settingsCellTrailingInset()
    }
}
