import SwiftUI

enum MapperSymbols {
    /// The menu-bar mark stays intentionally lightweight at small template sizes.
    static let menuBar = "command"
    static let mappings = "keyboard"
}

enum SettingsMetrics {
    static let pageInset: CGFloat = 24
    static let sectionSpacing: CGFloat = 24
    static let sidebarWidth: CGFloat = 184
    static let statusSpacing: CGFloat = 4
    static let trailingContentInset: CGFloat = 0
    static let rowSpacing: CGFloat = 10
    static let rowVerticalPadding: CGFloat = 10
    static let rowIconSize: CGFloat = 24
    static let rowTextInset: CGFloat = rowIconSize + rowSpacing
    static let pageContentWidth: CGFloat = 700
    static let surfaceHorizontalInset: CGFloat = 16
    static let surfaceVerticalInset: CGFloat = 4
    static let surfaceCornerRadius: CGFloat = 14
    static let keyCornerRadius: CGFloat = 12
    static let bodyFont = Font.system(size: 13)
    static let secondaryFont = Font.system(size: 12)
    static let sectionTitle = Font.system(size: 12, weight: .semibold)
    static let pageTitle = Font.system(size: 20, weight: .semibold)
    static let detailTitle = bodyFont.weight(.semibold)
}

/// Navigation uses native sidebar typography and selection colors in both windows and sheets.
struct SettingsSidebar<Selection: Hashable, Content: View>: View {
    @Binding var selection: Selection?
    @ViewBuilder var content: Content

    var body: some View {
        List(selection: $selection) { content }
            .listStyle(.sidebar)
            .font(nil)
    }
}

struct SettingsStatusLabel: View {
    let title: String
    let systemName: String
    let color: Color

    var body: some View {
        HStack(spacing: SettingsMetrics.statusSpacing) {
            Image(systemName: systemName)
                .accessibilityHidden(true)
            Text(title)
        }
        .font(SettingsMetrics.secondaryFont)
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }
}

struct SettingsPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SettingsMetrics.sectionSpacing) {
                Text(title)
                    .font(SettingsMetrics.pageTitle)
                    .accessibilityAddTraits(.isHeader)
                content
            }
            .frame(maxWidth: SettingsMetrics.pageContentWidth, alignment: .leading)
            .padding(SettingsMetrics.pageInset)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .font(SettingsMetrics.bodyFont)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// One shared surface and spacing rule for the two settings pages.
struct SettingsGroup<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(SettingsMetrics.sectionTitle)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
                    .padding(.horizontal, 2)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 0) { content }
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .groupBoxStyle(SettingsSurfaceStyle())
        }
    }
}

private struct SettingsSurfaceStyle: GroupBoxStyle {
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.content
            .padding(.horizontal, SettingsMetrics.surfaceHorizontalInset)
            .padding(.vertical, SettingsMetrics.surfaceVerticalInset)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: SettingsMetrics.surfaceCornerRadius, style: .continuous))
            .overlay {
                if contrast == .increased {
                    RoundedRectangle(cornerRadius: SettingsMetrics.surfaceCornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
                        .allowsHitTesting(false)
                }
            }
    }
}

struct SettingsRowIcon: View {
    let systemName: String
    var tint = Color(nsColor: .secondaryLabelColor)

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(tint)
            .frame(width: SettingsMetrics.rowIconSize, height: SettingsMetrics.rowIconSize)
            .accessibilityHidden(true)
    }
}

struct SettingsRowToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: SettingsMetrics.rowSpacing) {
            configuration.label
            Spacer(minLength: 12)
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

struct SettingsRowLabel: View {
    let systemName: String
    let title: String
    var detail: String? = nil
    var tint = Color(nsColor: .secondaryLabelColor)

    var body: some View {
        HStack(spacing: SettingsMetrics.rowSpacing) {
            SettingsRowIcon(systemName: systemName, tint: tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(SettingsMetrics.bodyFont)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(SettingsMetrics.secondaryFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct SettingsDisclosureRow: View {
    let systemName: String
    let title: String
    let language: AppLanguage
    @Binding var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.16)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: SettingsMetrics.rowSpacing) {
                SettingsRowLabel(systemName: systemName, title: title)
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .accessibilityHidden(true)
            }
            .settingsCellTrailingInset()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, SettingsMetrics.rowVerticalPadding)
        .accessibilityLabel(title)
        .accessibilityValue(isExpanded ? language.text("已展开", "Expanded") : language.text("已折叠", "Collapsed"))
        .accessibilityHint(language.text("展开或折叠详情", "Expand or collapse details"))
    }
}

struct SystemPermissionRow: View {
    let kind: PermissionKind
    let state: PermissionUIState
    let language: AppLanguage
    let openSettings: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: SettingsMetrics.rowSpacing) {
                label.fixedSize()
                Spacer(minLength: 12)
                controls.fixedSize()
            }
            VStack(alignment: .leading, spacing: 6) {
                label
                controls.padding(.leading, SettingsMetrics.rowIconSize + SettingsMetrics.rowSpacing)
            }
        }
        .padding(.vertical, SettingsMetrics.rowVerticalPadding)
        .settingsCellTrailingInset()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(kind.title(language: language)), \(state.title(language: language))")
    }

    private var label: some View {
        SettingsRowLabel(systemName: kind.symbol, title: kind.title(language: language))
            .help(kind.explanation(language: language))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            PermissionStatusLabel(state: state, language: language).font(SettingsMetrics.secondaryFont)
            if state != .granted {
                SettingsActionButton(language.text("设置", "Settings"), action: openSettings)
            }
        }
    }
}

struct SettingsDivider: View {
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Divider().opacity(contrast == .increased ? 1 : 0.4)
    }
}

/// Shared native bezel and label metrics keep short actions the same size.
struct SettingsActionButton: View {
    let title: String
    var role: ButtonRole? = nil
    var prominent = false
    let action: () -> Void

    init(_ title: String, role: ButtonRole? = nil, prominent: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.prominent = prominent
        self.action = action
    }

    var body: some View {
        Group {
            if prominent { button.buttonStyle(.borderedProminent) }
            else { button.buttonStyle(.bordered) }
        }
        .controlSize(.small)
    }

    private var button: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(SettingsMetrics.bodyFont)
                .frame(minWidth: 56, minHeight: 18)
        }
    }
}

extension View {
    func settingsCellTrailingInset() -> some View {
        padding(.trailing, SettingsMetrics.trailingContentInset)
    }

}
