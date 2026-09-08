import XCTest
import CodexMicroCore

final class MappingModelsTests: XCTestCase {
    func testDefaultProfileUsesTwoCoreActionTypesAndACT12Adapter() {
        let profile = MappingProfile.defaults

        XCTAssertEqual(profile.bindings.map(\.control), [
            .act06,
            .act07,
            .act08,
            .act09,
            .wideMicrophone,
            .act12,
        ])
        XCTAssertEqual(profile.action(for: .act06), .keyStroke(.commandN))
        XCTAssertEqual(
            profile.action(for: .act07),
            .toggleApplication(.codex, afterActivation: .controlThree)
        )
        XCTAssertEqual(
            profile.action(for: .act08),
            .toggleApplication(.chatGPTClassic, afterActivation: nil)
        )
        XCTAssertEqual(
            profile.action(for: .act09),
            .toggleApplication(.googleChrome, afterActivation: nil)
        )
        XCTAssertEqual(
            profile.action(for: .wideMicrophone),
            .keyStroke(.home)
        )
        XCTAssertEqual(
            profile.action(for: .act12),
            .verifiedPlaceholderReturn(
                placeholder: ":yolo:",
                returnKeyStroke: .returnKey
            )
        )
    }

    func testProfileAndAssociatedActionsRoundTripThroughJSON() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(MappingProfile.defaults)
        let decoded = try JSONDecoder().decode(MappingProfile.self, from: data)

        XCTAssertEqual(decoded, .defaults)
    }

    func testGeneralPurposeActionsRoundTripThroughJSON() throws {
        try assertRoundTrip(MappingAction.activateApplication(.codex, afterActivation: nil))
        try assertRoundTrip(MappingAction.openTarget(.webURL("https://chatgpt.com")))
        try assertRoundTrip(MappingAction.openTarget(.file("/tmp/example.txt")))
        try assertRoundTrip(MappingAction.openTarget(.folder("/tmp")))
        try assertRoundTrip(MappingAction.runShortcut(name: "Focus Mode"))
    }

    func testEventAndActionResultRoundTripThroughJSON() throws {
        try assertRoundTrip(
            HIDKeyEvent(key: .act08, phase: .down, agent: "agent-1")
        )
        try assertRoundTrip(
            LogicalKeyEvent(control: .wideMicrophone, phase: .up, sourceKey: .act11)
        )
        try assertRoundTrip(ActionResult.success)
        try assertRoundTrip(ActionResult.skipped(reason: "Typeless is not running"))
        try assertRoundTrip(ActionResult.failure(reason: "Event posting denied"))
    }

    func testSetActionUpdatesWithoutDuplicatingControl() {
        var profile = MappingProfile.defaults
        profile.setAction(.disabled, for: .act06)

        XCTAssertNil(profile.action(for: .act06))
        XCTAssertEqual(profile.bindings.filter { $0.control == .act06 }.count, 1)
    }

    private func assertRoundTrip<Value: Codable & Equatable>(_ value: Value) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(Value.self, from: data)
        XCTAssertEqual(decoded, value)
    }
}
