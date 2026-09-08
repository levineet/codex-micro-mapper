import Foundation

public struct PermissionSnapshot: Sendable, Equatable {
    public let inputMonitoringGranted: Bool
    public let accessibilityGranted: Bool
    public let eventPostingGranted: Bool

    public init(
        inputMonitoringGranted: Bool,
        accessibilityGranted: Bool,
        eventPostingGranted: Bool
    ) {
        self.inputMonitoringGranted = inputMonitoringGranted
        self.accessibilityGranted = accessibilityGranted
        self.eventPostingGranted = eventPostingGranted
    }

    public var canListenToDevice: Bool {
        inputMonitoringGranted
    }

    public var canExecuteMappings: Bool {
        accessibilityGranted && eventPostingGranted
    }
}

public struct LegacyProcessDescriptor: Sendable, Equatable {
    public let processIdentifier: Int32
    public let bundleIdentifier: String?
    public let executableName: String?
    public let executablePath: String?
    public let bundlePath: String?
    public let localizedName: String?

    public init(
        processIdentifier: Int32,
        bundleIdentifier: String?,
        executableName: String?,
        executablePath: String?,
        bundlePath: String?,
        localizedName: String?
    ) {
        self.processIdentifier = processIdentifier
        self.bundleIdentifier = bundleIdentifier
        self.executableName = executableName
        self.executablePath = executablePath
        self.bundlePath = bundlePath
        self.localizedName = localizedName
    }
}

public struct LegacyHelperIdentity: Sendable, Equatable {
    public static let `default` = LegacyHelperIdentity(
        bundleIdentifier: "local.codex.micro.typeless-helper",
        executableNames: ["CodexMicroTypelessHelper"],
        bundlePaths: ["/Applications/Codex Micro Mapping.app"]
    )

    public let bundleIdentifier: String
    public let executableNames: Set<String>
    public let bundlePaths: Set<String>

    public init(
        bundleIdentifier: String,
        executableNames: Set<String>,
        bundlePaths: Set<String>
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.executableNames = executableNames
        self.bundlePaths = bundlePaths
    }

    public func matches(_ process: LegacyProcessDescriptor) -> Bool {
        if process.bundleIdentifier == bundleIdentifier {
            return true
        }

        if let executableName = process.executableName,
           executableNames.contains(executableName) {
            return true
        }

        if let executablePath = process.executablePath,
           executableNames.contains(URL(fileURLWithPath: executablePath).lastPathComponent) {
            return true
        }

        if let bundlePath = process.bundlePath {
            let standardizedPath = URL(fileURLWithPath: bundlePath).standardizedFileURL.path
            return bundlePaths.contains {
                URL(fileURLWithPath: $0).standardizedFileURL.path == standardizedPath
            }
        }

        return false
    }
}

public struct LegacyHelperConflict: Sendable, Equatable, Identifiable {
    public let process: LegacyProcessDescriptor

    public init(process: LegacyProcessDescriptor) {
        self.process = process
    }

    public var id: Int32 {
        process.processIdentifier
    }

    public var displayName: String {
        process.localizedName ?? process.executableName ?? "Codex Micro Mapping"
    }
}

public enum LaunchAtLoginState: String, Sendable, Equatable, CaseIterable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

public enum LaunchAtLoginOperation: Sendable, Equatable {
    case none
    case register
    case unregister
    case openApprovalSettings
}

public enum LaunchAtLoginDecision {
    public static func operation(
        currentState: LaunchAtLoginState,
        requestedEnabled: Bool
    ) -> LaunchAtLoginOperation {
        switch (currentState, requestedEnabled) {
        case (.enabled, true), (.disabled, false), (.unavailable, false):
            return .none
        case (.requiresApproval, true):
            return .openApprovalSettings
        case (_, true):
            return .register
        case (.enabled, false), (.requiresApproval, false):
            return .unregister
        }
    }
}

public struct CodexMicroDeviceDescriptor: Sendable, Equatable {
    public let productName: String
    public let transport: String
    public let vendorID: Int
    public let productID: Int
    public let registryEntryID: UInt64?

    public init(
        productName: String,
        transport: String,
        vendorID: Int,
        productID: Int,
        registryEntryID: UInt64?
    ) {
        self.productName = productName
        self.transport = transport
        self.vendorID = vendorID
        self.productID = productID
        self.registryEntryID = registryEntryID
    }
}

public enum CodexMicroHIDConnectionState: Sendable, Equatable {
    case stopped
    case listening
    case connected(CodexMicroDeviceDescriptor)
    case failed(String)
}
