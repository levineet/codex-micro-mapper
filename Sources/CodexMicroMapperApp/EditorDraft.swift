import CodexMicroCore

enum EditorKind: Hashable { case shortcut, application }

enum EditorFrontmostBehavior: Hashable { case keepVisible, hide }

struct EditorDraft {
    var kind = EditorKind.shortcut
    var isEnabled: Bool
    var shortcut: KeyStrokeDefinition?
    var application: ApplicationTarget?
    var frontmostBehavior: EditorFrontmostBehavior?
    var sendsFollowUp = false
    var followUp: KeyStrokeDefinition?
    var preservesLegacy = false

    init(_ binding: MappingBinding) {
        isEnabled = binding.isUnassigned || binding.isEnabled
        switch binding.action {
        case let .keyStroke(key): shortcut = key
        case let .toggleApplication(app, key):
            kind = .application; application = app; followUp = key; sendsFollowUp = key != nil; frontmostBehavior = .hide
        case let .activateApplication(app, key):
            kind = .application; application = app; followUp = key; sendsFollowUp = key != nil; frontmostBehavior = .keepVisible
        case let .verifiedPlaceholderReturn(_, key):
            shortcut = key
            preservesLegacy = binding.control != .act12
        case let .typelessRecordingToggle(_, key):
            shortcut = key; preservesLegacy = true
        case .openTarget, .runShortcut: preservesLegacy = true
        case .disabled: break
        }
        if binding.unrecognizedAction != nil { preservesLegacy = true; isEnabled = binding.isEnabled }
    }

    func binding(for original: MappingBinding) -> MappingBinding? {
        if preservesLegacy {
            var preserved = original
            preserved.isEnabled = isEnabled
            return preserved
        }
        let action: MappingAction?
        switch kind {
        case .shortcut:
            action = shortcut.map { key in
                original.control == .act12
                    ? .verifiedPlaceholderReturn(placeholder: ":yolo:", returnKeyStroke: key)
                    : .keyStroke(key)
            }
        case .application:
            if let application, let frontmostBehavior, !sendsFollowUp || followUp != nil {
                action = frontmostBehavior == .hide
                    ? .toggleApplication(application, afterActivation: sendsFollowUp ? followUp : nil)
                    : .activateApplication(application, afterActivation: sendsFollowUp ? followUp : nil)
            } else { action = nil }
        }
        guard let action else {
            guard !original.isUnassigned, !isEnabled else { return nil }
            var preserved = original
            preserved.isEnabled = false
            return preserved
        }
        return MappingBinding(control: original.control, action: action, isEnabled: isEnabled)
    }
}
