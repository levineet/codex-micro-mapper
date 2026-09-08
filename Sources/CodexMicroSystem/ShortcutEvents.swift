import CoreGraphics
import CodexMicroCore

extension ModifierKey {
    var eventFlags: CGEventFlags {
        let raw: UInt64
        switch self {
        case .leftControl: raw = CGEventFlags.maskControl.rawValue | 0x1
        case .rightControl: raw = CGEventFlags.maskControl.rawValue | 0x2000
        case .leftShift: raw = CGEventFlags.maskShift.rawValue | 0x2
        case .rightShift: raw = CGEventFlags.maskShift.rawValue | 0x4
        case .leftCommand: raw = CGEventFlags.maskCommand.rawValue | 0x8
        case .rightCommand: raw = CGEventFlags.maskCommand.rawValue | 0x10
        case .leftOption: raw = CGEventFlags.maskAlternate.rawValue | 0x20
        case .rightOption: raw = CGEventFlags.maskAlternate.rawValue | 0x40
        case .function: raw = CGEventFlags.maskSecondaryFn.rawValue
        }
        return CGEventFlags(rawValue: raw)
    }

    var deviceFlag: UInt64 { eventFlags.rawValue & 0xFFFF }
}

/// A complete press/release sequence. Modifier keys use flagsChanged, including
/// their device-specific side bits, rather than ordinary keyDown events.
struct ShortcutEventStep {
    let event: CGEvent
    let keyCode: UInt16
    let isDown: Bool
}

enum ShortcutEvents {
    static let sourceTag: Int64 = 0x434D4D4150504552

    static func make(_ definition: KeyStrokeDefinition) -> [ShortcutEventStep]? {
        guard let source = CGEventSource(stateID: .privateState) else { return nil }
        var steps: [ShortcutEventStep] = []
        var held: Set<ModifierKey> = []
        let capsLock = CGEventSource.flagsState(.combinedSessionState).intersection(.maskAlphaShift)

        func append(_ code: UInt16, down: Bool, isModifier: Bool) -> Bool {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { return false }
            if isModifier { event.type = .flagsChanged }
            event.flags = held.reduce(into: capsLock) { $0.formUnion($1.eventFlags) }
            event.setIntegerValueField(.eventSourceUserData, value: sourceTag)
            steps.append(ShortcutEventStep(event: event, keyCode: code, isDown: down))
            return true
        }

        let keys = definition.resolvedModifierKeys
        for key in keys {
            held.insert(key)
            guard append(key.rawValue, down: true, isModifier: true) else { return nil }
        }
        if !definition.isModifierOnly {
            guard append(definition.keyCode, down: true, isModifier: false),
                  append(definition.keyCode, down: false, isModifier: false) else { return nil }
        }
        for key in keys.reversed() {
            held.remove(key)
            guard append(key.rawValue, down: false, isModifier: true) else { return nil }
        }
        return steps
    }
}
