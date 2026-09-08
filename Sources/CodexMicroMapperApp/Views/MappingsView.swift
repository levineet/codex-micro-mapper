import CodexMicroCore
import SwiftUI

struct MappingsView: View {
    @ObservedObject var model: AppModel
    let selectedControl: PhysicalControl?
    let onEdit: (MappingBinding) -> Void
    let onSetUpPermissions: () -> Void
    @State private var confirmsLegacyTermination = false
    @State private var saveFailed = false

    var body: some View {
        SettingsPage(title: model.language.text("按键映射", "Mappings")) {
            SettingsGroup {
                Toggle(isOn: Binding(get: { model.isEnabled }, set: { value in
                    if value != model.isEnabled { model.toggleEnabled() }
                })) {
                    SettingsRowLabel(systemName: "power", title: model.language.text("启用按键映射", "Enable key mappings"))
                }
                .toggleStyle(SettingsRowToggleStyle())
                .padding(.vertical, SettingsMetrics.rowVerticalPadding)
                .settingsCellTrailingInset()
            }

            SettingsGroup {
                HStack(spacing: SettingsMetrics.rowSpacing) {
                    SettingsRowLabel(systemName: "keyboard", title: "Codex Micro")
                    Spacer(minLength: 12)
                    DeviceStatusLabel(model: model)
                    if !model.permissions.canListenToDevice || !model.permissions.canExecuteMappings {
                        SettingsActionButton(model.language.text("设置权限", "Set Up Permissions"), action: onSetUpPermissions)
                    }
                }
                .padding(.vertical, SettingsMetrics.rowVerticalPadding)
                .settingsCellTrailingInset()

                SettingsDivider()

                KeyboardLayoutView(
                    bindings: model.profile.bindings,
                    language: model.language,
                    highlightedControl: model.highlightedControl,
                    selectedControl: selectedControl,
                    onSelect: onEdit,
                    onToggle: { binding in
                        var updated = binding
                        updated.isEnabled.toggle()
                        saveFailed = !model.editBinding(updated)
                    }
                )
            }

            if model.legacyHelperRunning {
                SettingsGroup {
                    LegacyHelperWarning(model: model) { confirmsLegacyTermination = true }
                }
            }
        }
        .alert(model.language.text("无法保存按键设置", "Couldn’t Save Key Mapping"), isPresented: $saveFailed) {
            Button(model.language.text("好", "OK"), role: .cancel) {}
        } message: {
            Text(model.language.text("原有设置已保留，请重试。", "Your settings are unchanged. Try again."))
        }
        .alert(model.language.text("退出旧版助手？", "Quit the Legacy Helper?"), isPresented: $confirmsLegacyTermination) {
            Button(model.language.text("取消", "Cancel"), role: .cancel) {}
            Button(model.language.text("退出旧版助手", "Quit Legacy Helper"), role: .destructive) { model.terminateLegacyHelper() }
        } message: {
            Text(model.language.text("退出 Codex Micro Mapping 后，本应用即可接收键盘按键。", "Quit Codex Micro Mapping so this app can receive key presses."))
        }
    }
}
