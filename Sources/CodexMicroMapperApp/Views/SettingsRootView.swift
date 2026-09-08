import AppKit
import CodexMicroCore
import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var model: AppModel
    @State private var selectedSection: SettingsSection? = .mappings
    @State private var presentedSheet: SettingsSheet?

    private var editorSelection: MappingEditorSelection? {
        if case let .editor(selection) = presentedSheet { selection } else { nil }
    }

    var body: some View {
        NavigationSplitView {
            SettingsSidebar(selection: $selectedSection) {
                Label(model.language.text("按键映射", "Mappings"), systemImage: MapperSymbols.mappings)
                    .tag(SettingsSection.mappings)
                Label(model.language.text("通用", "General"), systemImage: "gearshape")
                    .tag(SettingsSection.general)
            }
            .navigationSplitViewColumnWidth(min: 164, ideal: SettingsMetrics.sidebarWidth, max: 224)
        } detail: {
            detail
                .navigationTitle("Codex Micro Mapper")
        }
            .navigationSplitViewStyle(.balanced)
            .environment(\.locale, model.language.locale)
            .accessibilityLabel(model.language.text("Codex Micro Mapper 设置", "Codex Micro Mapper settings"))
            .sheet(item: $presentedSheet, onDismiss: presentPendingPermissionOnboarding) { sheet in
                switch sheet {
                case let .editor(selection):
                    MappingEditorSheet(
                        binding: selection.binding,
                        language: model.language,
                        onSave: model.editBinding,
                        onRecordingChanged: model.setRecordingShortcut
                    )
                case .permissions:
                    PermissionOnboardingSheet(model: model)
                }
            }
            .onChange(of: model.permissionOnboardingRequest.isPending, initial: true) { _, _ in
                presentPendingPermissionOnboarding()
            }

    }

    @ViewBuilder private var detail: some View {
        switch selectedSection ?? .mappings {
        case .mappings:
            MappingsView(model: model, selectedControl: editorSelection?.binding.control,
                         onEdit: { presentedSheet = .editor(MappingEditorSelection(binding: $0)) },
                         onSetUpPermissions: { presentedSheet = .permissions })
        case .general:
            GeneralView(model: model)
        }
    }

    private func presentPendingPermissionOnboarding() {
        guard model.permissionOnboardingRequest.isPending else { return }
        if case .permissions = presentedSheet {
            _ = model.takePermissionOnboardingRequest()
        } else if presentedSheet == nil, model.takePermissionOnboardingRequest() {
            presentedSheet = .permissions
        }
    }
}

private enum SettingsSection: Hashable { case mappings, general }

private struct MappingEditorSelection: Identifiable {
    let id = UUID()
    let binding: MappingBinding
}

private enum SettingsSheet: Identifiable {
    case editor(MappingEditorSelection)
    case permissions

    var id: String {
        switch self {
        case let .editor(selection): "editor-\(selection.id)"
        case .permissions: "permissions"
        }
    }
}
