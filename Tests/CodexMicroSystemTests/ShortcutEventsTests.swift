import XCTest
import CoreGraphics
import CodexMicroCore
@testable import CodexMicroSystem

final class ShortcutEventsTests: XCTestCase {
    func testRightOptionProducesFlagsChangedWithRightSideAndCompleteRelease() throws {
        let steps = try XCTUnwrap(ShortcutEvents.make(.rightOption))
        XCTAssertEqual(steps.count, 2)
        XCTAssertEqual(steps.map(\.keyCode), [61, 61])
        XCTAssertEqual(steps.map(\.isDown), [true, false])
        XCTAssertTrue(steps.allSatisfy { $0.event.type == .flagsChanged })
        XCTAssertTrue(steps[0].event.flags.contains(.maskAlternate))
        XCTAssertEqual(steps[0].event.flags.rawValue & 0x60, 0x40)
        XCTAssertFalse(steps[1].event.flags.contains(.maskAlternate))
        XCTAssertEqual(steps[1].event.flags.rawValue & 0x60, 0)
    }

    func testOrdinaryChordHasModifierDownBeforeAndUpAfterMainKey() throws {
        let steps = try XCTUnwrap(ShortcutEvents.make(.commandN))
        XCTAssertEqual(steps.map(\.keyCode), [55, 45, 45, 55])
        XCTAssertEqual(steps.map { $0.event.type }, [.flagsChanged, .keyDown, .keyUp, .flagsChanged])
        XCTAssertTrue(steps[1].event.flags.contains(.maskCommand))
        XCTAssertFalse(steps[3].event.flags.contains(.maskCommand))
    }

    func testBothOptionSidesKeepGenericFlagUntilLastRelease() throws {
        let chord = KeyStrokeDefinition(keyCode: 0, modifiers: .option, modifierKeys: [.leftOption, .rightOption])
        let steps = try XCTUnwrap(ShortcutEvents.make(chord))
        XCTAssertEqual(steps.map(\.keyCode), [58, 61, 0, 0, 61, 58])
        XCTAssertEqual(steps[1].event.flags.rawValue & 0x60, 0x60)
        XCTAssertTrue(steps[4].event.flags.contains(.maskAlternate))
        XCTAssertEqual(steps[4].event.flags.rawValue & 0x60, 0x20)
        XCTAssertFalse(steps[5].event.flags.contains(.maskAlternate))
    }

    func testHomeHasNoModifierEvents() throws {
        let steps = try XCTUnwrap(ShortcutEvents.make(.home))
        XCTAssertEqual(steps.map { $0.event.type }, [.keyDown, .keyUp])
        XCTAssertEqual(steps.map(\.keyCode), [115, 115])
        XCTAssertTrue(steps.allSatisfy { $0.event.getIntegerValueField(.eventSourceUserData) == ShortcutEvents.sourceTag })
    }
}
