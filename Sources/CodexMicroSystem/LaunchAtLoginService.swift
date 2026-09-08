import AppKit
import Foundation
import ServiceManagement

@MainActor
public final class LaunchAtLoginService {
    private let service: SMAppService

    public init(service: SMAppService = .mainApp) {
        self.service = service
    }

    public var state: LaunchAtLoginState {
        switch service.status {
        case .notRegistered:
            return .disabled
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    @discardableResult
    public func setEnabled(_ enabled: Bool) throws -> LaunchAtLoginState {
        switch LaunchAtLoginDecision.operation(currentState: state, requestedEnabled: enabled) {
        case .none:
            break
        case .register:
            try service.register()
        case .unregister:
            try service.unregister()
        case .openApprovalSettings:
            SMAppService.openSystemSettingsLoginItems()
        }
        return state
    }

    public func openApprovalSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
