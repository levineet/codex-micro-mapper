import Foundation

/// Platform-neutral modifier bits. CodexMicroSystem is responsible for mapping
/// these values to CGEventFlags.
public struct KeyModifiers: OptionSet, Hashable, Sendable, Codable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(UInt16.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let shift = Self(rawValue: 1 << 0)
    public static let control = Self(rawValue: 1 << 1)
    public static let option = Self(rawValue: 1 << 2)
    public static let command = Self(rawValue: 1 << 3)
    public static let function = Self(rawValue: 1 << 4)
}

public struct KeyStrokeDefinition: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var modifiers: KeyModifiers
    public var modifierKeys: [ModifierKey]

    public init(keyCode: UInt16, modifiers: KeyModifiers = [], modifierKeys: [ModifierKey] = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.modifierKeys = modifierKeys
    }

    private enum CodingKeys: String, CodingKey { case keyCode, modifiers, modifierKeys }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        modifiers = try container.decodeIfPresent(KeyModifiers.self, forKey: .modifiers) ?? []
        modifierKeys = try container.decodeIfPresent([ModifierKey].self, forKey: .modifierKeys) ?? []
    }

    public var isModifierOnly: Bool { ModifierKey(rawValue: keyCode) != nil }

    /// Old profiles did not retain a side; choose the conventional left key
    /// only for those unsided flags. Recorded keys retain their exact side.
    public var resolvedModifierKeys: [ModifierKey] {
        var keys = Set(modifierKeys)
        if let key = ModifierKey(rawValue: keyCode) { keys.insert(key) }
        for key in ModifierKey.defaultKeys where modifiers.contains(key.modifier) {
            if !keys.contains(where: { $0.modifier == key.modifier }) { keys.insert(key) }
        }
        return keys.sorted { $0.rawValue < $1.rawValue }
    }

    // Hardware-independent macOS virtual key codes used by the default profile.
    public static let commandN = Self(keyCode: 45, modifiers: .command)
    public static let controlThree = Self(keyCode: 20, modifiers: .control)
    public static let rightOption = Self(keyCode: ModifierKey.rightOption.rawValue)
    public static let home = Self(keyCode: 115)
    public static let returnKey = Self(keyCode: 36)
}

public struct ApplicationTarget: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var bundleIdentifier: String
    public var displayName: String

    public init(bundleIdentifier: String, displayName: String) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
    }

    public var id: String { bundleIdentifier }

    public static let codex = Self(
        bundleIdentifier: "com.openai.codex",
        displayName: "Codex"
    )
    public static let chatGPTClassic = Self(
        bundleIdentifier: "com.openai.chat",
        displayName: "ChatGPT Classic"
    )
    public static let googleChrome = Self(
        bundleIdentifier: "com.google.Chrome",
        displayName: "Google Chrome"
    )
    public static let typeless = Self(
        bundleIdentifier: "now.typeless.desktop",
        displayName: "Typeless"
    )
}

public enum OpenTarget: Codable, Equatable, Sendable {
    case webURL(String)
    case file(String)
    case folder(String)
}

public enum MappingAction: Codable, Equatable, Sendable {
    /// Post the shortcut to whichever application is currently in front.
    case keyStroke(KeyStrokeDefinition)

    /// Hide the target when it is frontmost; otherwise launch/activate it and
    /// optionally post a shortcut after activation settles.
    case toggleApplication(
        ApplicationTarget,
        afterActivation: KeyStrokeDefinition?
    )

    /// Launch or activate the target every time. Unlike toggleApplication,
    /// pressing the physical key while the app is frontmost keeps it visible.
    case activateApplication(
        ApplicationTarget,
        afterActivation: KeyStrokeDefinition?
    )

    /// Open a URL, file, or folder through the system workspace.
    case openTarget(OpenTarget)

    /// Run a named shortcut from the user's macOS Shortcuts library.
    case runShortcut(name: String)

    /// Post the given toggle shortcut only if Typeless is already running.
    case typelessRecordingToggle(
        target: ApplicationTarget,
        keyStroke: KeyStrokeDefinition
    )

    /// Delete only a focus-safe, AX-verified exact placeholder selection, then
    /// post the supplied Return keystroke whether cleanup is performed or not.
    case verifiedPlaceholderReturn(
        placeholder: String,
        returnKeyStroke: KeyStrokeDefinition
    )

    case disabled
}

public struct MappingBinding: Codable, Equatable, Sendable, Identifiable {
    public var control: PhysicalControl
    public var action: MappingAction
    public var isEnabled: Bool
    /// Preserve an unknown future/legacy action verbatim instead of discarding
    /// the entire user's profile when one binding cannot be interpreted.
    public private(set) var unrecognizedAction: JSONValue?

    public init(control: PhysicalControl, action: MappingAction, isEnabled: Bool = true) {
        self.control = control
        self.action = action
        self.isEnabled = isEnabled
    }

    private enum CodingKeys: String, CodingKey { case control, action, isEnabled }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        control = try container.decode(PhysicalControl.self, forKey: .control)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        let rawAction = try container.decode(JSONValue.self, forKey: .action)
        if let decoded = try? JSONDecoder().decode(MappingAction.self, from: JSONEncoder().encode(rawAction)) {
            action = decoded
        } else {
            action = .disabled
            unrecognizedAction = rawAction
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(control, forKey: .control)
        try container.encode(isEnabled, forKey: .isEnabled)
        if let unrecognizedAction {
            try container.encode(unrecognizedAction, forKey: .action)
        } else {
            try container.encode(action, forKey: .action)
        }
    }

    public var isActive: Bool { isEnabled && action != .disabled && unrecognizedAction == nil }

    public var isUnassigned: Bool { action == .disabled && unrecognizedAction == nil }

    public var id: PhysicalControl { control }
}

public struct MappingProfile: Codable, Equatable, Sendable {
    public var bindings: [MappingBinding]

    public init(bindings: [MappingBinding]) {
        self.bindings = bindings
    }

    public func action(for control: PhysicalControl) -> MappingAction? {
        bindings.first(where: { $0.control == control && $0.isActive })?.action
    }

    public mutating func setBinding(_ binding: MappingBinding) {
        if let index = bindings.firstIndex(where: { $0.control == binding.control }) {
            bindings[index] = binding
        } else { bindings.append(binding) }
    }

    public mutating func setAction(_ action: MappingAction, for control: PhysicalControl) {
        if let index = bindings.firstIndex(where: { $0.control == control }) {
            bindings[index] = MappingBinding(control: control, action: action, isEnabled: bindings[index].isEnabled)
        } else {
            bindings.append(MappingBinding(control: control, action: action))
        }
    }

    public static let empty = Self(bindings: [
        PhysicalControl.act06, .act07, .act08, .act09, .wideMicrophone, .act12,
    ].map { MappingBinding(control: $0, action: .disabled) })

    public static let defaults = Self(bindings: [
        MappingBinding(
            control: .act06,
            action: .keyStroke(.commandN)
        ),
        MappingBinding(
            control: .act07,
            action: .toggleApplication(.codex, afterActivation: .controlThree)
        ),
        MappingBinding(
            control: .act08,
            action: .toggleApplication(.chatGPTClassic, afterActivation: nil)
        ),
        MappingBinding(
            control: .act09,
            action: .toggleApplication(.googleChrome, afterActivation: nil)
        ),
        MappingBinding(
            control: .wideMicrophone,
            action: .keyStroke(.home)
        ),
        MappingBinding(
            control: .act12,
            action: .verifiedPlaceholderReturn(
                placeholder: ":yolo:",
                returnKeyStroke: .returnKey
            )
        ),
    ])
}

public enum ActionResult: Codable, Equatable, Sendable {
    case success
    case skipped(reason: String)
    case failure(reason: String)

    public var succeeded: Bool {
        if case .success = self { return true }
        return false
    }
}
