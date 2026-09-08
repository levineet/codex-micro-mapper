import AppKit
import SwiftUI
import CodexMicroCore
import CodexMicroSystem

enum ViewFormatting {
    static func controlTitle(_ control: PhysicalControl) -> String {
        let raw = String(describing: control)
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        if raw.contains("ACT10") && raw.contains("ACT11") {
            return "ACT10 + ACT11"
        }

        if let range = raw.range(of: #"ACT\d{2}"#, options: .regularExpression) {
            return String(raw[range])
        }

        if raw.contains("WIDEMIC") || raw.contains("MICROPHONE") {
            return "ACT10 + ACT11"
        }

        return String(describing: control)
    }

    static func actionTitle(_ action: MappingAction) -> String {
        switch action {
        case .disabled:
            return "Not set"
        case .keyStroke:
            return "Keyboard Shortcut"
        case let .toggleApplication(target, _):
            return applicationName(target)
        case let .activateApplication(target, _):
            return applicationName(target)
        case let .openTarget(target):
            return openTargetTitle(target)
        case let .runShortcut(name):
            return name
        case .typelessRecordingToggle:
            return "Typeless"
        case .verifiedPlaceholderReturn:
            return "Return"
        }
    }

    static func actionTitle(for binding: MappingBinding) -> String {
        actionTitle(for: binding, language: .english)
    }

    static func applicationIcon(for action: MappingAction) -> NSImage? {
        let target: ApplicationTarget
        switch action {
        case let .toggleApplication(application, _):
            target = application
        case let .activateApplication(application, _):
            target = application
        case let .typelessRecordingToggle(application, _):
            target = application
        default:
            return nil
        }

        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: target.bundleIdentifier
        ) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    static func actionDetail(_ action: MappingAction) -> String {
        switch action {
        case .disabled:
            return "No action"
        case let .keyStroke(shortcut):
            return shortcutText(shortcut)
        case let .toggleApplication(_, afterActivation):
            if let afterActivation {
                return "Show / Hide · then \(shortcutText(afterActivation))"
            }
            return "Show / Hide"
        case let .activateApplication(_, afterActivation):
            if let afterActivation {
                return "Bring to Front · then \(shortcutText(afterActivation))"
            }
            return "Bring to Front"
        case let .openTarget(target):
            return openTargetDetail(target)
        case .runShortcut:
            return "Run macOS Shortcut"
        case .typelessRecordingToggle:
            return "Toggle Recording"
        case .verifiedPlaceholderReturn:
            return "Clean exact :yolo: then press Return"
        }
    }

    static func actionSymbol(_ action: MappingAction) -> String {
        switch action {
        case .disabled:
            return "nosign"
        case .keyStroke:
            return "keyboard"
        case .toggleApplication, .activateApplication:
            return "macwindow"
        case let .openTarget(target):
            switch target {
            case .webURL: return "link"
            case .file: return "doc"
            case .folder: return "folder"
            }
        case .runShortcut:
            return "square.stack.3d.up.fill"
        case .typelessRecordingToggle:
            return "waveform"
        case .verifiedPlaceholderReturn:
            return "return"
        }
    }

    static func applicationName(_ target: ApplicationTarget) -> String {
        reflectedString(in: target, labels: ["displayName", "name", "localizedName"])
            ?? applicationIdentifier(target)
    }

    static func applicationIdentifier(_ target: ApplicationTarget) -> String {
        reflectedString(in: target, labels: ["bundleIdentifier", "bundleID", "identifier"])
            ?? String(describing: target)
    }

    static func actionTitle(for binding: MappingBinding, language: AppLanguage) -> String {
        if binding.isUnassigned { return language.text("未设置", "Not set") }
        if !binding.isActive {
            return binding.unrecognizedAction != nil
                ? language.text("不支持的操作", "Unsupported Action")
                : language.text("已停用", "Disabled")
        }
        switch binding.action {
        case .disabled:
            return language.text("未设置", "Not set")
        case let .keyStroke(shortcut):
            return shortcutText(shortcut, language: language)
        case let .toggleApplication(target, _), let .activateApplication(target, _):
            return applicationName(target)
        case let .openTarget(target):
            return openTargetTitle(target)
        case let .runShortcut(name):
            return name.isEmpty ? language.text("macOS 快捷指令", "macOS Shortcut") : name
        case .typelessRecordingToggle:
            return language.text("Typeless 录音", "Typeless Recording")
        case let .verifiedPlaceholderReturn(_, shortcut):
            return shortcut == .returnKey ? language.text("回车", "Return") : shortcutText(shortcut, language: language)
        }
    }

    static func actionDetail(_ action: MappingAction, language: AppLanguage) -> String {
        switch action {
        case .disabled:
            return language.text("未设置", "Not set")
        case let .keyStroke(shortcut):
            return shortcutText(shortcut, language: language)
        case let .toggleApplication(_, afterActivation):
            let base = language.text("前台时隐藏", "Hide when in front")
            guard let afterActivation else { return base }
            return "\(base) · \(language.text("随后", "then")) \(shortcutText(afterActivation, language: language))"
        case let .activateApplication(_, afterActivation):
            let base = language.text("切到前台", "Bring to front")
            guard let afterActivation else { return base }
            return "\(base) · \(language.text("随后", "then")) \(shortcutText(afterActivation, language: language))"
        case let .openTarget(target):
            return openTargetDetail(target)
        case .runShortcut:
            return language.text("运行快捷指令", "Run Shortcut")
        case .typelessRecordingToggle:
            return language.text("Typeless 运行时发送 Home", "Send Home while Typeless is running")
        case .verifiedPlaceholderReturn:
            return language.text("验证 :yolo: 后发送快捷键", "Verify :yolo:, then send shortcut")
        }
    }

    static func physicalPosition(_ control: PhysicalControl, language: AppLanguage) -> String {
        switch control.id {
        case PhysicalControl.act06.id: return language.text("下排第 1 键", "Lower row · key 1")
        case PhysicalControl.act07.id: return language.text("下排第 2 键", "Lower row · key 2")
        case PhysicalControl.act08.id: return language.text("下排第 3 键", "Lower row · key 3")
        case PhysicalControl.act09.id: return language.text("下排第 4 键", "Lower row · key 4")
        case PhysicalControl.wideMicrophone.id: return language.text("底部宽键", "Bottom wide key")
        case PhysicalControl.act12.id: return language.text("底部右键", "Bottom-right key")
        default: return controlTitle(control)
        }
    }

    static func officialSetting(_ control: PhysicalControl) -> String {
        switch control.id {
        case PhysicalControl.act06.id: return "Empty 1"
        case PhysicalControl.act07.id: return "Empty 2"
        case PhysicalControl.act08.id: return "Empty 3"
        case PhysicalControl.act09.id: return "Empty 4"
        case PhysicalControl.wideMicrophone.id: return "Empty 5"
        case PhysicalControl.act12.id: return "Yolo"
        default: return "—"
        }
    }

    private static func openTargetTitle(_ target: OpenTarget) -> String {
        switch target {
        case let .webURL(rawValue):
            return URL(string: rawValue)?.host ?? rawValue
        case let .file(path), let .folder(path):
            return URL(fileURLWithPath: path).lastPathComponent
        }
    }

    private static func openTargetDetail(_ target: OpenTarget) -> String {
        switch target {
        case let .webURL(rawValue): return rawValue
        case let .file(path), let .folder(path): return path
        }
    }

    static func modifierName(_ key: ModifierKey, language: AppLanguage) -> String {
        switch key {
        case .leftCommand: language.text("左 Command", "Left Command")
        case .rightCommand: language.text("右 Command", "Right Command")
        case .leftOption: language.text("左 Option", "Left Option")
        case .rightOption: language.text("右 Option", "Right Option")
        case .leftControl: language.text("左 Control", "Left Control")
        case .rightControl: language.text("右 Control", "Right Control")
        case .leftShift: language.text("左 Shift", "Left Shift")
        case .rightShift: language.text("右 Shift", "Right Shift")
        case .function: "fn"
        }
    }

    static func shortcutText(_ shortcut: KeyStrokeDefinition, language: AppLanguage = .english) -> String {
        let keys = shortcut.resolvedModifierKeys
        if shortcut.isModifierOnly {
            return keys.map { modifierName($0, language: language) }.joined(separator: " + ")
        }
        func symbol(_ left: ModifierKey, _ right: ModifierKey, _ glyph: String) -> String {
            let hasLeft = keys.contains(left), hasRight = keys.contains(right)
            if hasLeft && hasRight { return language.text("左", "L") + glyph + language.text("右", "R") + glyph }
            if hasRight { return language.text("右", "R") + glyph }
            return hasLeft ? glyph : ""
        }
        let prefix = symbol(.leftControl, .rightControl, "⌃")
            + symbol(.leftOption, .rightOption, "⌥")
            + symbol(.leftShift, .rightShift, "⇧")
            + symbol(.leftCommand, .rightCommand, "⌘")
            + (keys.contains(.function) ? "fn " : "")
        return prefix + keyName(for: shortcut.keyCode)
    }

    static func shortcutAccessibilityText(_ shortcut: KeyStrokeDefinition, language: AppLanguage) -> String {
        var parts = shortcut.resolvedModifierKeys.map { modifierName($0, language: language) }
        if !shortcut.isModifierOnly { parts.append(keyName(for: shortcut.keyCode)) }
        return parts.joined(separator: " + ")
    }

    static func keyName(for keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`",
            51: "⌫", 53: "⎋", 122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12", 115: "Home", 116: "Page Up", 117: "⌦",
            119: "End", 121: "Page Down", 123: "←", 124: "→", 125: "↓", 126: "↑",
            105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20",
        ]
        return names[keyCode] ?? "Key \(keyCode)"
    }

    private static func modifierText(_ value: Any?) -> String {
        guard let value else { return "" }
        let description = String(describing: value).lowercased()
        var output = ""

        if description.contains("control") || description.contains("ctrl") {
            output += "⌃"
        }
        if description.contains("option") || description.contains("alternate") || description.contains("alt") {
            output += "⌥"
        }
        if description.contains("shift") {
            output += "⇧"
        }
        if description.contains("command") || description.contains("cmd") {
            output += "⌘"
        }

        if !output.isEmpty {
            return output
        }

        guard let rawValue = reflectedInteger(in: value, labels: ["rawValue"]) else {
            return ""
        }

        // Match CodexMicroCore.KeyModifiers' serialized bit order.
        if rawValue & 2 != 0 { output += "⌃" }
        if rawValue & 4 != 0 { output += "⌥" }
        if rawValue & 1 != 0 { output += "⇧" }
        if rawValue & 8 != 0 { output += "⌘" }
        if rawValue & 16 != 0 { output += "fn" }
        return output
    }

    private static func reflectedString(in value: Any, labels: Set<String>) -> String? {
        guard let reflected = reflectedValue(in: value, labels: labels) else {
            return nil
        }
        return reflected as? String
    }

    private static func reflectedString(in value: Any, labels: [String]) -> String? {
        reflectedString(in: value, labels: Set(labels))
    }

    private static func reflectedInteger(in value: Any, labels: [String]) -> Int? {
        guard let reflected = reflectedValue(in: value, labels: Set(labels)) else {
            return nil
        }
        switch reflected {
        case let value as Int: return value
        case let value as UInt: return Int(value)
        case let value as UInt16: return Int(value)
        case let value as Int32: return Int(value)
        case let value as UInt32: return Int(value)
        default: return nil
        }
    }

    private static func reflectedValue(in value: Any, labels: [String]) -> Any? {
        reflectedValue(in: value, labels: Set(labels))
    }

    private static func reflectedValue(in value: Any, labels: Set<String>, depth: Int = 0) -> Any? {
        guard depth < 4 else { return nil }
        let mirror = Mirror(reflecting: value)

        for child in mirror.children {
            if let label = child.label, labels.contains(label) {
                return unwrapOptional(child.value)
            }
        }

        for child in mirror.children {
            if let match = reflectedValue(in: child.value, labels: labels, depth: depth + 1) {
                return match
            }
        }
        return nil
    }

    private static func unwrapOptional(_ value: Any) -> Any? {
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return value }
        return mirror.children.first?.value
    }
}

enum PermissionKind {
    case inputMonitoring
    case accessibility

    func title(language: AppLanguage) -> String {
        switch self {
        case .inputMonitoring: language.text("输入监控", "Input Monitoring")
        case .accessibility: language.text("辅助功能", "Accessibility")
        }
    }

    var title: String { title(language: .english) }

    var symbol: String {
        switch self {
        case .inputMonitoring: "keyboard.badge.eye"
        case .accessibility: "accessibility"
        }
    }

    func explanation(language: AppLanguage) -> String {
        switch self {
        case .inputMonitoring:
            language.text("接收 Codex Micro 按键", "Receive Codex Micro key presses")
        case .accessibility:
            language.text("发送快捷键、切换应用", "Send shortcuts and switch apps")
        }
    }

    var explanation: String { explanation(language: .english) }
}

enum PermissionUIState: Equatable {
    case granted
    case denied
    case unknown

    func title(language: AppLanguage) -> String {
        switch self {
        case .granted: language.text("已开启", "Enabled")
        case .denied: language.text("需开启", "Required")
        case .unknown: language.text("需检查", "Check Required")
        }
    }

    var title: String { title(language: .english) }

    var symbol: String {
        switch self {
        case .granted: "checkmark.circle.fill"
        case .denied: "exclamationmark.triangle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .granted: .green
        case .denied: .orange
        case .unknown: .secondary
        }
    }

    static func resolve(_ permissions: PermissionSnapshot, kind: PermissionKind) -> PermissionUIState {
        switch kind {
        case .inputMonitoring:
            return permissions.inputMonitoringGranted ? .granted : .denied
        case .accessibility:
            return permissions.canExecuteMappings ? .granted : .denied
        }
    }
}

struct PermissionStatusLabel: View {
    let state: PermissionUIState
    var language: AppLanguage = .english

    var body: some View {
        SettingsStatusLabel(title: state.title(language: language), systemName: state.symbol, color: state.color)
    }
}
