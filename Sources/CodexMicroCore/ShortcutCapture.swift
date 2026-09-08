import Foundation

public enum ModifierKey: UInt16, Codable, CaseIterable, Hashable, Sendable {
    case rightCommand = 54, leftCommand = 55, leftShift = 56
    case leftOption = 58, leftControl = 59, rightShift = 60
    case rightOption = 61, rightControl = 62, function = 63

    public var modifier: KeyModifiers {
        switch self {
        case .leftCommand, .rightCommand: .command
        case .leftShift, .rightShift: .shift
        case .leftOption, .rightOption: .option
        case .leftControl, .rightControl: .control
        case .function: .function
        }
    }

    public static let defaultKeys: [Self] = [.leftControl, .leftOption, .leftShift, .leftCommand, .function]
}

/// One recording lasts through all key releases, including modifiers released
/// before the main key. This reducer never posts or observes system events.
public struct ShortcutCapture: Sendable {
    public private(set) var pressedKeys: Set<UInt16> = []
    public private(set) var candidate: KeyStrokeDefinition?
    public private(set) var isCancelled = false
    private var hasMainKey = false

    public init() {}

    public var isFinished: Bool { pressedKeys.isEmpty && (candidate != nil || isCancelled) }

    public mutating func cancel() { isCancelled = true }

    public mutating func receive(keyCode: UInt16, phase: KeyPhase, modifiers: Set<ModifierKey>) {
        if phase == .up {
            pressedKeys.remove(keyCode)
            return
        }
        guard pressedKeys.insert(keyCode).inserted, !isCancelled else { return }
        if keyCode == 53 && modifiers.isEmpty {
            isCancelled = true
            return
        }
        let keys = modifiers.sorted { $0.rawValue < $1.rawValue }
        let flags = keys.reduce(into: KeyModifiers()) { $0.formUnion($1.modifier) }
        if ModifierKey(rawValue: keyCode) != nil {
            // Do not mistake the initial Option press for the finished shortcut.
            if !hasMainKey {
                candidate = KeyStrokeDefinition(keyCode: keyCode, modifiers: flags, modifierKeys: keys)
            }
        } else if !hasMainKey {
            hasMainKey = true
            candidate = KeyStrokeDefinition(keyCode: keyCode, modifiers: flags, modifierKeys: keys)
        }
    }
}
