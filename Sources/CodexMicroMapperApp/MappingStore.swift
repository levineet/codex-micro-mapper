import CodexMicroCore
import Foundation

struct MappingStore {
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
            return
        }

        let baseURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        let directoryURL = baseURL.appendingPathComponent(
            "Codex Micro Mapper",
            isDirectory: true
        )
        self.fileURL = directoryURL.appendingPathComponent("mappings.json")
    }

    func load() -> MappingProfile {
        guard
            let data = try? Data(contentsOf: fileURL),
            let profile = try? JSONDecoder().decode(MappingProfile.self, from: data)
        else {
            return .defaults
        }
        return profile.normalized()
    }

    func save(_ profile: MappingProfile) throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(profile.normalized())
        try data.write(to: fileURL, options: .atomic)
    }
}

private extension MappingProfile {
    func normalized() -> MappingProfile {
        var firstBindingByControl: [PhysicalControl: MappingBinding] = [:]
        for binding in bindings where firstBindingByControl[binding.control] == nil {
            firstBindingByControl[binding.control] = binding
        }

        let defaultControls = MappingProfile.defaults.bindings.map(\.control)
        var ordered = defaultControls.compactMap { firstBindingByControl.removeValue(forKey: $0) }
        ordered.append(contentsOf: firstBindingByControl.values.sorted { $0.control.id < $1.control.id })
        return MappingProfile(bindings: ordered)
    }
}
