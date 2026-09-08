import CodexMicroCore
@testable import CodexMicroMapper
import XCTest

final class EditorDraftTests: XCTestCase {
    private let original = MappingBinding(control: .act06, action: .keyStroke(.init(keyCode: 45, modifiers: [.command])))
    private let app = ApplicationTarget(bundleIdentifier: "example.app", displayName: "Example")

    func testNewApplicationRequiresBothExplicitSelections() {
        var draft = EditorDraft(original)
        draft.kind = .application
        XCTAssertNil(draft.application)
        XCTAssertNil(draft.frontmostBehavior)
        XCTAssertNil(draft.binding(for: original))

        draft.application = app
        XCTAssertNil(draft.binding(for: original))

        draft.frontmostBehavior = .keepVisible
        XCTAssertEqual(draft.binding(for: original)?.action, .activateApplication(app, afterActivation: nil))
        draft.frontmostBehavior = .hide
        XCTAssertEqual(draft.binding(for: original)?.action, .toggleApplication(app, afterActivation: nil))
    }

    func testExistingApplicationChoicesRoundTrip() {
        let followUp = KeyStrokeDefinition(keyCode: 20, modifiers: [.control])
        for action: MappingAction in [
            .toggleApplication(app, afterActivation: nil),
            .activateApplication(app, afterActivation: nil),
            .toggleApplication(app, afterActivation: followUp),
            .activateApplication(app, afterActivation: followUp),
        ] {
            for enabled in [true, false] {
                let binding = MappingBinding(control: .act07, action: action, isEnabled: enabled)
                XCTAssertEqual(EditorDraft(binding).binding(for: binding), binding)
            }
        }
    }

    func testRequestedFollowUpCannotSaveWithoutShortcut() {
        var draft = EditorDraft(original)
        draft.kind = .application
        draft.application = app
        draft.frontmostBehavior = .keepVisible
        draft.sendsFollowUp = true
        XCTAssertNil(draft.binding(for: original))
        draft.followUp = .init(keyCode: 49)
        XCTAssertEqual(draft.binding(for: original)?.action, .activateApplication(app, afterActivation: draft.followUp))
    }

    func testSwitchingEditorCategoriesRetainsDraftChoices() {
        var draft = EditorDraft(original)
        draft.kind = .application
        draft.application = app
        draft.frontmostBehavior = .hide
        draft.kind = .shortcut
        XCTAssertEqual(draft.binding(for: original), original)
        draft.kind = .application
        XCTAssertEqual(draft.binding(for: original)?.action, .toggleApplication(app, afterActivation: nil))
    }

    func testACT12ShortcutStillUsesVerifiedPlaceholderPath() {
        let original = MappingBinding(control: .act12, action: .verifiedPlaceholderReturn(placeholder: ":yolo:", returnKeyStroke: .returnKey))
        var draft = EditorDraft(original)
        let key = KeyStrokeDefinition(keyCode: 61)
        draft.shortcut = key
        XCTAssertEqual(draft.binding(for: original)?.action, .verifiedPlaceholderReturn(placeholder: ":yolo:", returnKeyStroke: key))
    }

    func testIncompleteDisabledDraftPreservesExistingAction() {
        var draft = EditorDraft(original)
        draft.kind = .application
        draft.isEnabled = false
        let saved = draft.binding(for: original)
        XCTAssertEqual(saved?.action, original.action)
        XCTAssertEqual(saved?.isEnabled, false)
    }

    func testUnassignedDraftHasNoPrefilledActionAndCannotSaveEmpty() {
        for binding in MappingProfile.empty.bindings {
            for previouslyEnabled in [true, false] {
                var original = binding
                original.isEnabled = previouslyEnabled
                var draft = EditorDraft(original)
                XCTAssertTrue(draft.isEnabled)
                XCTAssertNil(draft.shortcut)
                XCTAssertNil(draft.application)
                XCTAssertNil(draft.frontmostBehavior)
                XCTAssertNil(draft.followUp)
                XCTAssertFalse(draft.sendsFollowUp)
                XCTAssertFalse(draft.preservesLegacy)

                for kind: EditorKind in [.shortcut, .application] {
                    draft.kind = kind
                    for enabled in [true, false] {
                        draft.isEnabled = enabled
                        XCTAssertNil(draft.binding(for: original))
                    }
                }
            }
        }
    }

    func testUnassignedShortcutSavesAsActiveAfterSelection() throws {
        for binding in MappingProfile.empty.bindings where binding.control != .act12 {
            var draft = EditorDraft(binding)
            draft.shortcut = .rightOption
            let saved = try XCTUnwrap(draft.binding(for: binding))
            XCTAssertEqual(saved.control, binding.control)
            XCTAssertEqual(saved.action, .keyStroke(.rightOption))
            XCTAssertTrue(saved.isActive)
        }
    }

    func testUnassignedACT12ShortcutUsesVerifiedPlaceholderPath() throws {
        let binding = try XCTUnwrap(MappingProfile.empty.bindings.first { $0.control == .act12 })
        var draft = EditorDraft(binding)
        draft.shortcut = .returnKey
        let saved = try XCTUnwrap(draft.binding(for: binding))
        XCTAssertEqual(saved.action, .verifiedPlaceholderReturn(placeholder: ":yolo:", returnKeyStroke: .returnKey))
        XCTAssertTrue(saved.isActive)
    }

    func testUnassignedApplicationRequiresCompleteSelectionEvenWhenDisabled() throws {
        let binding = MappingBinding(control: .act07, action: .disabled)
        for enabled in [true, false] {
            var draft = EditorDraft(binding)
            draft.kind = .application
            draft.isEnabled = enabled
            draft.application = app
            XCTAssertNil(draft.binding(for: binding))

            draft.frontmostBehavior = .keepVisible
            draft.sendsFollowUp = true
            XCTAssertNil(draft.binding(for: binding))

            draft.followUp = .commandN
            let saved = try XCTUnwrap(draft.binding(for: binding))
            XCTAssertEqual(saved.action, .activateApplication(app, afterActivation: .commandN))
            XCTAssertEqual(saved.isEnabled, enabled)
        }
    }

    func testEditingConfiguredDisabledShortcutsKeepsThemDisabled() throws {
        for control: PhysicalControl in [.act06, .act12] {
            let action: MappingAction = control == .act12
                ? .verifiedPlaceholderReturn(placeholder: ":yolo:", returnKeyStroke: .returnKey)
                : .keyStroke(.commandN)
            let binding = MappingBinding(control: control, action: action, isEnabled: false)
            var draft = EditorDraft(binding)
            XCTAssertFalse(draft.isEnabled)
            XCTAssertEqual(draft.binding(for: binding), binding)

            draft.shortcut = .rightOption
            let saved = try XCTUnwrap(draft.binding(for: binding))
            XCTAssertFalse(saved.isEnabled)
            XCTAssertFalse(saved.isActive)
            XCTAssertFalse(saved.isUnassigned)
        }
    }

    func testUnrecognizedActionIsNotTreatedAsUnassigned() throws {
        let json = Data(#"{"control":"ACT06","action":{"futureAction":{"value":"preserve"}},"isEnabled":false}"#.utf8)
        let binding = try JSONDecoder().decode(MappingBinding.self, from: json)
        XCTAssertEqual(binding.action, .disabled)
        XCTAssertFalse(binding.isUnassigned)
        var draft = EditorDraft(binding)
        XCTAssertTrue(draft.preservesLegacy)
        XCTAssertFalse(draft.isEnabled)
        XCTAssertEqual(draft.binding(for: binding), binding)

        draft.preservesLegacy = false
        draft.kind = .application
        XCTAssertEqual(draft.binding(for: binding), binding)
    }
}
