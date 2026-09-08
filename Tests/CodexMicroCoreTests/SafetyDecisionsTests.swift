import XCTest
import CodexMicroCore

final class SafetyDecisionsTests: XCTestCase {
    func testAppToggleHidesOnlyWhenTargetIsFrontmost() {
        XCTAssertEqual(
            appToggleDecision(
                frontmostBundleIdentifier: ApplicationTarget.codex.bundleIdentifier,
                target: .codex
            ),
            .hide
        )
        XCTAssertEqual(
            appToggleDecision(
                frontmostBundleIdentifier: ApplicationTarget.chatGPTClassic.bundleIdentifier,
                target: .codex
            ),
            .activate
        )
        XCTAssertEqual(
            appToggleDecision(
                frontmostBundleIdentifier: nil,
                target: .googleChrome
            ),
            .activate
        )
    }

    func testPlaceholderDeletesOnlyExactVerifiedStableSelection() {
        XCTAssertEqual(
            placeholderCleanupDecision(
                selectedText: ":yolo:",
                isTargetProcessUnchanged: true,
                isFocusedElementUnchanged: true
            ),
            .deleteSelection
        )

        let unsafeInputs: [(String?, Bool, Bool)] = [
            (nil, true, true),
            ("yolo", true, true),
            (":YOLO:", true, true),
            (":yolo:", false, true),
            (":yolo:", true, false),
            (":yolo:", false, false),
        ]
        for (text, sameProcess, sameElement) in unsafeInputs {
            XCTAssertEqual(
                placeholderCleanupDecision(
                    selectedText: text,
                    isTargetProcessUnchanged: sameProcess,
                    isFocusedElementUnchanged: sameElement
                ),
                .preserveSelection
            )
        }
    }

    func testEmptyExpectedPlaceholderCanNeverDelete() {
        XCTAssertEqual(
            placeholderCleanupDecision(
                selectedText: "",
                expectedPlaceholder: "",
                isTargetProcessUnchanged: true,
                isFocusedElementUnchanged: true
            ),
            .preserveSelection
        )
    }
}
