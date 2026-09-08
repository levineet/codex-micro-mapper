import XCTest
@testable import CodexMicroCore

final class ShortcutCaptureTests: XCTestCase {
    func testRightOptionCompletesOnlyAfterRelease() {
        var capture = ShortcutCapture()
        capture.receive(keyCode: 61, phase: .down, modifiers: [.rightOption])
        XCTAssertFalse(capture.isFinished)
        XCTAssertEqual(capture.candidate?.resolvedModifierKeys, [.rightOption])
        capture.receive(keyCode: 61, phase: .up, modifiers: [])
        XCTAssertTrue(capture.isFinished)
        XCTAssertTrue(capture.candidate?.isModifierOnly == true)
        XCTAssertFalse(capture.isCancelled)
    }

    func testModifierCanBecomeChordAndEarlyModifierReleasePreservesSide() {
        var capture = ShortcutCapture()
        capture.receive(keyCode: 59, phase: .down, modifiers: [.leftControl])
        capture.receive(keyCode: 61, phase: .down, modifiers: [.leftControl, .rightOption])
        capture.receive(keyCode: 40, phase: .down, modifiers: [.leftControl, .rightOption])
        capture.receive(keyCode: 61, phase: .up, modifiers: [.leftControl])
        capture.receive(keyCode: 59, phase: .up, modifiers: [])
        XCTAssertFalse(capture.isFinished)
        capture.receive(keyCode: 40, phase: .up, modifiers: [])
        XCTAssertTrue(capture.isFinished)
        XCTAssertEqual(capture.candidate?.keyCode, 40)
        XCTAssertEqual(capture.candidate?.resolvedModifierKeys, [.leftControl, .rightOption])
    }

    func testRepeatedDownAndASecondMainKeyDoNotReplaceTheFirstKey() {
        var capture = ShortcutCapture()
        capture.receive(keyCode: 115, phase: .down, modifiers: [])
        capture.receive(keyCode: 115, phase: .down, modifiers: [])
        capture.receive(keyCode: 119, phase: .down, modifiers: [])
        capture.receive(keyCode: 115, phase: .up, modifiers: [])
        XCTAssertFalse(capture.isFinished)
        capture.receive(keyCode: 119, phase: .up, modifiers: [])
        XCTAssertEqual(capture.candidate, .home)
        XCTAssertTrue(capture.isFinished)
    }

    func testEscapeCancelsButReturnAndDeleteAreRecordable() {
        var escape = ShortcutCapture()
        escape.receive(keyCode: 53, phase: .down, modifiers: [])
        XCTAssertTrue(escape.isCancelled)
        XCTAssertFalse(escape.isFinished)
        escape.receive(keyCode: 53, phase: .up, modifiers: [])
        XCTAssertTrue(escape.isFinished)
        XCTAssertNil(escape.candidate)
        for code: UInt16 in [36, 51] {
            var capture = ShortcutCapture()
            capture.receive(keyCode: code, phase: .down, modifiers: [])
            capture.receive(keyCode: code, phase: .up, modifiers: [])
            XCTAssertEqual(capture.candidate?.keyCode, code)
            XCTAssertFalse(capture.isCancelled)
        }
    }

    func testCancellationWaitsForTheKeysItOwns() {
        var capture = ShortcutCapture()
        capture.receive(keyCode: 61, phase: .down, modifiers: [.rightOption])
        capture.cancel()
        XCTAssertFalse(capture.isFinished)
        capture.receive(keyCode: 61, phase: .up, modifiers: [])
        XCTAssertTrue(capture.isFinished)
        XCTAssertTrue(capture.isCancelled)
    }

    func testOlderShortcutJSONDecodesAndNewSideInformationSurvivesRestart() throws {
        let old = Data(#"{"keyCode":45,"modifiers":8}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(KeyStrokeDefinition.self, from: old), .commandN)
        let shortcut = KeyStrokeDefinition(keyCode: 40, modifiers: [.control, .option], modifierKeys: [.rightControl, .rightOption])
        let restored = try JSONDecoder().decode(KeyStrokeDefinition.self, from: JSONEncoder().encode(shortcut))
        XCTAssertEqual(restored, shortcut)
        XCTAssertEqual(Set(restored.resolvedModifierKeys), [.rightControl, .rightOption])
    }

    func testDisabledBindingRetainsItsConfiguredAction() throws {
        var profile = MappingProfile.defaults
        profile.setBinding(MappingBinding(control: .wideMicrophone, action: .keyStroke(.rightOption), isEnabled: false))
        let restored = try JSONDecoder().decode(MappingProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertNil(restored.action(for: .wideMicrophone))
        var binding = try XCTUnwrap(restored.bindings.first { $0.control == .wideMicrophone })
        XCTAssertEqual(binding.action, .keyStroke(.rightOption))
        binding.isEnabled = true
        profile.setBinding(binding)
        XCTAssertEqual(profile.action(for: .wideMicrophone), .keyStroke(.rightOption))
    }

    func testAnUnknownActionDoesNotDiscardOtherBindingsAndIsPreserved() throws {
        let raw = Data(#"{"bindings":[{"control":"ACT06","action":{"futureAction":{"name":"Example","version":3}}},{"control":"ACT07","action":{"keyStroke":{"_0":{"keyCode":115,"modifiers":0}}}}]}"#.utf8)
        let profile = try JSONDecoder().decode(MappingProfile.self, from: raw)
        XCTAssertEqual(profile.bindings.count, 2)
        XCTAssertNil(profile.action(for: .act06))
        XCTAssertEqual(profile.action(for: .act07), .keyStroke(.home))
        let again = try JSONDecoder().decode(MappingProfile.self, from: JSONEncoder().encode(profile))
        XCTAssertEqual(again, profile)
        XCTAssertNotNil(again.bindings[0].unrecognizedAction)
    }

    func testLegacyTypelessConditionIsNotSilentlyConverted() throws {
        let binding = MappingBinding(control: .wideMicrophone, action: .typelessRecordingToggle(target: .typeless, keyStroke: .home))
        let restored = try JSONDecoder().decode(MappingBinding.self, from: JSONEncoder().encode(binding))
        XCTAssertEqual(restored.action, binding.action)
    }
}
