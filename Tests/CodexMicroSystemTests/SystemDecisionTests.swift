import Foundation
import Testing
@testable import CodexMicroSystem

@Suite("System decisions")
struct SystemDecisionTests {
    @Test("Legacy helper identity accepts every supported identity signal")
    func legacyIdentitySignals() {
        let identity = LegacyHelperIdentity.default
        let base = LegacyProcessDescriptor(
            processIdentifier: 42,
            bundleIdentifier: nil,
            executableName: nil,
            executablePath: nil,
            bundlePath: nil,
            localizedName: nil
        )

        #expect(identity.matches(.init(
            processIdentifier: base.processIdentifier,
            bundleIdentifier: "local.codex.micro.typeless-helper",
            executableName: nil,
            executablePath: nil,
            bundlePath: nil,
            localizedName: nil
        )))
        #expect(identity.matches(.init(
            processIdentifier: base.processIdentifier,
            bundleIdentifier: nil,
            executableName: "CodexMicroTypelessHelper",
            executablePath: nil,
            bundlePath: nil,
            localizedName: nil
        )))
        #expect(identity.matches(.init(
            processIdentifier: base.processIdentifier,
            bundleIdentifier: nil,
            executableName: nil,
            executablePath: "/Applications/Codex Micro Mapping.app/Contents/MacOS/CodexMicroTypelessHelper",
            bundlePath: nil,
            localizedName: nil
        )))
        #expect(identity.matches(.init(
            processIdentifier: base.processIdentifier,
            bundleIdentifier: nil,
            executableName: nil,
            executablePath: nil,
            bundlePath: "/Applications/Codex Micro Mapping.app/",
            localizedName: nil
        )))
    }

    @Test("Unrelated processes do not block the mapper")
    func unrelatedProcessDoesNotMatch() {
        let process = LegacyProcessDescriptor(
            processIdentifier: 7,
            bundleIdentifier: "local.codex.micro.mapper",
            executableName: "CodexMicroMapper",
            executablePath: "/Applications/Codex Micro Mapper.app/Contents/MacOS/CodexMicroMapper",
            bundlePath: "/Applications/Codex Micro Mapper.app",
            localizedName: "Codex Micro Mapper"
        )
        #expect(!LegacyHelperIdentity.default.matches(process))
    }

    @Test(arguments: [
        (LaunchAtLoginState.disabled, true, LaunchAtLoginOperation.register),
        (.enabled, true, .none),
        (.requiresApproval, true, .openApprovalSettings),
        (.enabled, false, .unregister),
        (.requiresApproval, false, .unregister),
        (.disabled, false, .none),
        (.unavailable, false, .none),
    ])
    func launchAtLoginDecision(
        state: LaunchAtLoginState,
        requested: Bool,
        expected: LaunchAtLoginOperation
    ) {
        #expect(LaunchAtLoginDecision.operation(
            currentState: state,
            requestedEnabled: requested
        ) == expected)
    }

    @Test("Permission snapshot keeps listening and execution capabilities separate")
    func permissionCapabilities() {
        let listenOnly = PermissionSnapshot(
            inputMonitoringGranted: true,
            accessibilityGranted: false,
            eventPostingGranted: false
        )
        #expect(listenOnly.canListenToDevice)
        #expect(!listenOnly.canExecuteMappings)

        let executionOnly = PermissionSnapshot(
            inputMonitoringGranted: false,
            accessibilityGranted: true,
            eventPostingGranted: true
        )
        #expect(!executionOnly.canListenToDevice)
        #expect(executionOnly.canExecuteMappings)
    }
}
