import Foundation
import Testing
@testable import CodexMicroSystem

@Suite("Single instance guard", .serialized)
@MainActor
struct SingleInstanceGuardTests {
    @Test("A second guard cannot acquire the same live lock")
    func secondGuardIsRejected() throws {
        let lockURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("instance.lock")
        let first = SingleInstanceGuard(lockFileURL: lockURL)
        let second = SingleInstanceGuard(lockFileURL: lockURL)

        #expect(try first.acquire() == .acquired)
        #expect(try second.acquire() == .alreadyRunning)

        first.releaseLock()
        second.releaseLock()
    }

    @Test("A released lock can be acquired again")
    func releasedLockCanBeAcquired() throws {
        let lockURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("instance.lock")
        let first = SingleInstanceGuard(lockFileURL: lockURL)
        let second = SingleInstanceGuard(lockFileURL: lockURL)

        #expect(try first.acquire() == .acquired)
        first.releaseLock()
        #expect(try second.acquire() == .acquired)
        second.releaseLock()
    }
}
