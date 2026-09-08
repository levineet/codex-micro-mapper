import CodexMicroCore
@testable import CodexMicroMapper
import Foundation
import XCTest

final class MappingStoreTests: XCTestCase {
    func testEmptyProfileContainsSixUnassignedControlsAndNoActions() {
        let profile = MappingProfile.empty
        XCTAssertEqual(profile.bindings.map(\.control), [
            .act06, .act07, .act08, .act09, .wideMicrophone, .act12,
        ])
        XCTAssertEqual(Set(profile.bindings.map(\.control)).count, 6)
        for binding in profile.bindings {
            XCTAssertTrue(binding.isUnassigned)
            XCTAssertTrue(binding.isEnabled)
            XCTAssertFalse(binding.isActive)
            XCTAssertNil(profile.action(for: binding.control))
        }
    }

    func testEmptyProfileReplacesSavedMappingsAndSurvivesReload() throws {
        try withTemporaryStore { fileURL in
            let store = MappingStore(fileURL: fileURL)
            var populated = MappingProfile.defaults
            populated.setBinding(MappingBinding(control: .key(.init(rawValue: "ACT99")), action: .keyStroke(.home)))
            try store.save(populated)
            XCTAssertEqual(store.load(), populated)

            try store.save(.empty)
            let reloaded = MappingStore(fileURL: fileURL).load()
            XCTAssertEqual(reloaded, .empty)
            XCTAssertTrue(reloaded.bindings.allSatisfy(\.isUnassigned))
            XCTAssertTrue(reloaded.bindings.allSatisfy { reloaded.action(for: $0.control) == nil })
        }
    }

    func testValidEmptyBindingListDoesNotFallBackToDefaults() throws {
        try withTemporaryStore { fileURL in
            let store = MappingStore(fileURL: fileURL)
            XCTAssertEqual(store.load(), .defaults)
            let emptyList = MappingProfile(bindings: [])
            try store.save(emptyList)
            XCTAssertEqual(MappingStore(fileURL: fileURL).load(), emptyList)
        }
    }

    private func withTemporaryStore(_ body: (URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexMicroMapper-MappingStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try body(directory.appendingPathComponent("mappings.json"))
    }
}
