import XCTest
import CodexMicroCore

final class KeyEventReducerTests: XCTestCase {
    func testOrdinaryKeyEmitsOnlyRealPressEdges() {
        var reducer = KeyEventReducer()

        XCTAssertEqual(
            reducer.reduce(HIDKeyEvent(key: .act06, phase: .down)),
            LogicalKeyEvent(control: .act06, phase: .down, sourceKey: .act06)
        )
        XCTAssertNil(reducer.reduce(HIDKeyEvent(key: .act06, phase: .down)))
        XCTAssertEqual(
            reducer.reduce(HIDKeyEvent(key: .act06, phase: .up)),
            LogicalKeyEvent(control: .act06, phase: .up, sourceKey: .act06)
        )
        XCTAssertNil(reducer.reduce(HIDKeyEvent(key: .act06, phase: .up)))
    }

    func testWideKeyCoalescesOverlappingSwitchOrder() {
        var reducer = KeyEventReducer()

        XCTAssertEqual(
            reducer.reduce(HIDKeyEvent(key: .act10, phase: .down)),
            LogicalKeyEvent(control: .wideMicrophone, phase: .down, sourceKey: .act10)
        )
        XCTAssertNil(reducer.reduce(HIDKeyEvent(key: .act10, phase: .down)))
        XCTAssertNil(reducer.reduce(HIDKeyEvent(key: .act11, phase: .down)))
        XCTAssertNil(reducer.reduce(HIDKeyEvent(key: .act10, phase: .up)))
        XCTAssertEqual(
            reducer.reduce(HIDKeyEvent(key: .act11, phase: .up)),
            LogicalKeyEvent(control: .wideMicrophone, phase: .up, sourceKey: .act11)
        )
    }

    func testWideKeyCoalescesReverseReleaseOrder() {
        var reducer = KeyEventReducer()

        XCTAssertEqual(
            reducer.reduce(HIDKeyEvent(key: .act11, phase: .down))?.phase,
            .down
        )
        XCTAssertNil(reducer.reduce(HIDKeyEvent(key: .act10, phase: .down)))
        XCTAssertNil(reducer.reduce(HIDKeyEvent(key: .act11, phase: .up)))
        XCTAssertEqual(
            reducer.reduce(HIDKeyEvent(key: .act10, phase: .up))?.phase,
            .up
        )
    }

    func testResetMakesHeldOrdinaryAndWideKeysPressableAgain() {
        var reducer = KeyEventReducer()
        XCTAssertNotNil(reducer.reduce(HIDKeyEvent(key: .act07, phase: .down)))
        XCTAssertNotNil(reducer.reduce(HIDKeyEvent(key: .act10, phase: .down)))

        reducer.reset()

        XCTAssertEqual(
            reducer.reduce(HIDKeyEvent(key: .act07, phase: .down))?.phase,
            .down
        )
        XCTAssertEqual(
            reducer.reduce(HIDKeyEvent(key: .act10, phase: .down))?.phase,
            .down
        )
    }

    func testUnknownPhysicalKeyRemainsMappable() {
        var reducer = KeyEventReducer()
        let futureKey = RawPhysicalKey(rawValue: "ACT42")

        XCTAssertEqual(
            reducer.reduce(HIDKeyEvent(key: futureKey, phase: .down)),
            LogicalKeyEvent(
                control: .key(futureKey),
                phase: .down,
                sourceKey: futureKey
            )
        )
    }
}
