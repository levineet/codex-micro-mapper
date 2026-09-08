import AppKit
import SwiftUI

struct PermissionOnboardingSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    private var isReady: Bool {
        model.permissions.inputMonitoringGranted && model.permissions.canExecuteMappings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 12) {
                MapperAppIcon()

                VStack(alignment: .leading, spacing: 5) {
                    Text(isReady
                         ? model.language.text("权限已开启", "Permissions Enabled")
                         : model.language.text("请先开启权限", "Enable Permissions"))
                        .font(SettingsMetrics.pageTitle)
                        .accessibilityAddTraits(.isHeader)
                    if !isReady {
                        Text(model.language.text(
                            "在系统设置中允许本应用使用以下权限。",
                            "Allow access in System Settings to use key mappings."
                        ))
                        .font(SettingsMetrics.bodyFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            SettingsGroup {
                permissionRow(.inputMonitoring) {
                    model.requestInputMonitoring()
                    model.openInputMonitoringSettings()
                }
                SettingsDivider()
                permissionRow(.accessibility) {
                    model.requestAccessibility()
                    model.openAccessibilitySettings()
                }
            }

            HStack(spacing: 12) {
                Spacer(minLength: 0)
                if isReady {
                    SettingsActionButton(model.language.text("完成", "Done"), prominent: true) { dismiss() }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button(model.language.text("稍后设置", "Set Up Later")) { dismiss() }
                        .font(SettingsMetrics.bodyFont)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(.horizontal, SettingsMetrics.surfaceHorizontalInset)
        }
        .padding(SettingsMetrics.pageInset)
        .frame(width: 488)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.locale, model.language.locale)
    }

    private func permissionRow(_ kind: PermissionKind, openSettings: @escaping () -> Void) -> some View {
        HStack(spacing: SettingsMetrics.rowSpacing) {
            SettingsRowLabel(
                systemName: kind.symbol,
                title: kind.title(language: model.language),
                detail: kind.explanation(language: model.language)
            )
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            if PermissionUIState.resolve(model.permissions, kind: kind) == .granted {
                PermissionStatusLabel(state: .granted, language: model.language)
                    .font(SettingsMetrics.secondaryFont)
                    .fixedSize()
            } else {
                SettingsActionButton(model.language.text("前往设置", "Open Settings"), action: openSettings)
                    .fixedSize()
            }
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(kind.title(language: model.language))
    }
}
