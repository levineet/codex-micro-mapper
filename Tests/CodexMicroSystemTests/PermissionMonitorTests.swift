import CoreFoundation
import Foundation
@testable import CodexMicroSystem
import XCTest

final class PermissionMonitorTests: XCTestCase {
    @MainActor
    func testTracksGrantAndRevocationInCommonTrackingMode() {
        let denied = PermissionSnapshot(inputMonitoringGranted: false, accessibilityGranted: false, eventPostingGranted: false)
        let granted = PermissionSnapshot(inputMonitoringGranted: true, accessibilityGranted: true, eventPostingGranted: true)
        var current = denied
        var received: [PermissionSnapshot] = []
        let monitor = PermissionMonitor(interval: 0.01) { current }
        monitor.onSnapshot = { received.append($0) }
        monitor.start()
        defer { monitor.stop() }
        XCTAssertEqual(received, [denied], "The initial state is published synchronously.")

        // This is deliberately not the default run-loop mode: menus and modal
        // tracking loops used to pause the app's default-mode permission timer.
        let mode = CFRunLoopMode(rawValue: "CodexPermissionTrackingTest" as CFString)
        CFRunLoopAddCommonMode(CFRunLoopGetMain(), mode)
        current = granted
        CFRunLoopRunInMode(mode, 0.05, false)
        XCTAssertEqual(received.last, granted)
        current = denied
        CFRunLoopRunInMode(mode, 0.05, false)
        XCTAssertEqual(received.last, denied, "Revocation is also delivered while tracking.")
    }

    @MainActor
    func testLifecycleRefreshIsImmediateAndStopDiscardsFurtherChecks() {
        var current = PermissionSnapshot(inputMonitoringGranted: false, accessibilityGranted: true, eventPostingGranted: false)
        var reads = 0
        var received: [PermissionSnapshot] = []
        let monitor = PermissionMonitor(interval: 0.01) {
            reads += 1
            return current
        }
        monitor.onSnapshot = { received.append($0) }
        monitor.start()
        monitor.start()
        XCTAssertEqual(reads, 1, "A repeated start does not add a second polling timer.")

        current = .init(inputMonitoringGranted: true, accessibilityGranted: true, eventPostingGranted: false)
        monitor.refresh()
        XCTAssertEqual(received.last, current)
        XCTAssertFalse(received.last!.canExecuteMappings, "Input grants do not mask Event Posting denial.")

        monitor.stop()
        let countAfterStop = reads
        monitor.refresh()
        CFRunLoopRunInMode(.defaultMode, 0.04, false)
        XCTAssertEqual(reads, countAfterStop)
        XCTAssertFalse(monitor.isRunning)

        current = .init(inputMonitoringGranted: true, accessibilityGranted: true, eventPostingGranted: true)
        monitor.start()
        XCTAssertEqual(reads, countAfterStop + 1)
        XCTAssertEqual(received.last, current, "Recovery starts with a fresh snapshot.")
        monitor.stop()
    }

    @MainActor
    func testSnapshotHandlerCanStopMonitoringWithoutLeavingATimer() {
        var reads = 0
        let monitor = PermissionMonitor(interval: 0.01) {
            reads += 1
            return .init(inputMonitoringGranted: false, accessibilityGranted: false, eventPostingGranted: false)
        }
        monitor.onSnapshot = { [weak monitor] _ in monitor?.stop() }
        monitor.start()
        XCTAssertFalse(monitor.isRunning)
        CFRunLoopRunInMode(.defaultMode, 0.04, false)
        XCTAssertEqual(reads, 1)
    }
}
