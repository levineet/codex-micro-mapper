import AppKit
import CodexMicroCore
import SwiftUI

private enum KeyboardGeometry {
    static let topRow: [PhysicalControl] = [.act06, .act07, .act08, .act09]
    static let actionIconSize: CGFloat = 56
}

struct KeyboardLayoutView: View {
    let bindings: [MappingBinding]
    let language: AppLanguage
    var highlightedControl: PhysicalControl?
    var selectedControl: PhysicalControl?
    let onSelect: (MappingBinding) -> Void
    let onToggle: (MappingBinding) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                ForEach(KeyboardGeometry.topRow) { control in key(control) }
            }
            GridRow {
                Circle().fill(Color.primary.opacity(0.08))
                    .frame(width: 48, height: 48)
                    .frame(maxWidth: .infinity, minHeight: 104)
                    .accessibilityHidden(true)
                key(.wideMicrophone).gridCellColumns(2)
                key(.act12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SettingsMetrics.surfaceHorizontalInset)
        // The surrounding group supplies the remaining bottom inset.
        .padding(.bottom, SettingsMetrics.surfaceHorizontalInset - SettingsMetrics.surfaceVerticalInset)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: highlightedControl)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(language.text("Codex Micro 按键布局", "Codex Micro key layout"))
    }

    private func key(_ control: PhysicalControl) -> some View {
        let binding = bindings.first { $0.control == control } ?? MappingBinding(control: control, action: .disabled)
        let isPaused = !binding.isEnabled && !binding.isUnassigned && binding.unrecognizedAction == nil
        return Button { onSelect(binding) } label: {
            VStack(spacing: 8) {
                if binding.isUnassigned {
                    ActionSymbol(name: "plus", size: KeyboardGeometry.actionIconSize, showsTile: true, isMuted: true)
                } else {
                    ActionGlyph(action: binding.action, size: KeyboardGeometry.actionIconSize, showsSystemSymbolTile: true)
                }
                Text(previewTitle(binding))
                    .font(SettingsMetrics.bodyFont.weight(.medium))
                    .foregroundStyle(binding.isUnassigned ? .secondary : .primary)
                    .lineLimit(2).multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(binding.isActive || binding.isUnassigned ? 1 : 0.45)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 104)
            .overlay(alignment: .topTrailing) {
                if isPaused {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: SettingsMetrics.keyCornerRadius, style: .continuous))
        }
        .buttonStyle(KeyboardKeyButtonStyle(isHighlighted: highlightedControl == control || selectedControl == control))
        .accessibilityLabel(ViewFormatting.physicalPosition(control, language: language))
        .accessibilityValue(isPaused ? language.text("已停用，", "Disabled, ") + previewTitle(binding) : previewTitle(binding))
        .accessibilityHint(language.text("编辑按键", "Edit key"))
        .help("\(ViewFormatting.physicalPosition(control, language: language)) · \(ViewFormatting.controlTitle(control))")
        .contextMenu {
            Button(language.text("编辑按键", "Edit Key")) { onSelect(binding) }
            Divider()
            Button(binding.isEnabled ? language.text("停用按键", "Disable Key") : language.text("启用按键", "Enable Key")) {
                onToggle(binding)
            }
            .disabled(binding.action == .disabled || binding.unrecognizedAction != nil)
        }
    }

    private func previewTitle(_ binding: MappingBinding) -> String {
        if binding.unrecognizedAction != nil { return language.text("不支持的操作", "Unsupported Action") }
        switch binding.action {
        case let .toggleApplication(app, _), let .activateApplication(app, _):
            switch app.bundleIdentifier {
            case ApplicationTarget.chatGPTClassic.bundleIdentifier: return "ChatGPT"
            case ApplicationTarget.googleChrome.bundleIdentifier: return "Chrome"
            default: return app.displayName
            }
        default:
            var displayBinding = binding
            displayBinding.isEnabled = true
            return ViewFormatting.actionTitle(for: displayBinding, language: language)
        }
    }
}

private struct KeyboardKeyButtonStyle: ButtonStyle {
    let isHighlighted: Bool
    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: SettingsMetrics.keyCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SettingsMetrics.keyCornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.09 : (isHighlighted ? 0.07 : (isHovering ? 0.035 : 0))))
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: SettingsMetrics.keyCornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(contrast == .increased ? 0.35 : 0.08), lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.985 : (isHovering ? 1.012 : 1)))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovering)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { isHovering = $0 }
    }
}

/// A static guide to the required Codex device settings, not a mapping editor.
struct CodexSetupDiagram: View {
    let language: AppLanguage
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                ForEach(1...4, id: \.self) { key("Empty \($0)") }
            }
            GridRow {
                Circle().fill(Color.primary.opacity(0.07))
                    .frame(width: 20, height: 20)
                    .frame(maxWidth: .infinity, minHeight: 32)
                key("Empty 5").gridCellColumns(2)
                key("Yolo")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(language.text(
            "Codex 按键设置示意：下排四键从左到右设为 Empty 1、Empty 2、Empty 3、Empty 4；底部宽键设为 Empty 5；底部右键设为 Yolo。",
            "Codex key setup: set the lower four keys to Empty 1, Empty 2, Empty 3, Empty 4, from left to right; the bottom wide key to Empty 5; and the bottom-right key to Yolo."
        ))
    }

    private func key(_ title: String) -> some View {
        Text(title)
            .font(SettingsMetrics.secondaryFont)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                if contrast == .increased {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                }
            }
    }
}

/// A compact location cue; the text heading remains the accessible identity.
struct KeyLocationIndicator: View {
    let control: PhysicalControl

    var body: some View {
        Grid(horizontalSpacing: 4, verticalSpacing: 4) {
            GridRow {
                ForEach(KeyboardGeometry.topRow) { cell($0) }
            }
            GridRow {
                Circle().fill(Color.primary.opacity(0.08))
                    .frame(width: 12, height: 12).frame(width: 20, height: 14)
                cell(.wideMicrophone).gridCellColumns(2)
                cell(.act12)
            }
        }
        .accessibilityHidden(true)
    }

    private func cell(_ key: PhysicalControl) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(key == control ? Color.accentColor : Color.primary.opacity(0.08))
            .frame(width: key == .wideMicrophone ? 44 : 20, height: 14)
    }
}

struct ActionGlyph: View {
    let action: MappingAction
    var size: CGFloat = 22
    var showsSystemSymbolTile = false

    var body: some View {
        Group {
            if let icon = ViewFormatting.applicationIcon(for: action) {
                Image(nsImage: icon)
                    .renderingMode(.original)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
            } else {
                ActionSymbol(name: ViewFormatting.actionSymbol(action), size: size, showsTile: showsSystemSymbolTile, isMuted: isMuted)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var isMuted: Bool {
        if case .disabled = action { return true }
        return false
    }
}

private struct ActionSymbol: View {
    let name: String
    let size: CGFloat
    let showsTile: Bool
    let isMuted: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    // App icons include transparent margins. Match their visible silhouette.
    private var tileSize: CGFloat { size * 0.82 }

    var body: some View {
        Image(systemName: name)
            .font(.system(size: size * (showsTile ? 0.34 : 0.58), weight: .regular))
            .foregroundStyle(.secondary)
            .frame(width: tileSize, height: tileSize)
            .background {
                if showsTile {
                    RoundedRectangle(cornerRadius: tileSize * 0.22, style: .continuous)
                        .fill(Color.primary.opacity(0.055))
                        .overlay {
                            if contrast == .increased {
                                RoundedRectangle(cornerRadius: tileSize * 0.22, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.3), lineWidth: 1)
                            }
                        }
                }
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
