import AppKit
import ApplicationServices
import Foundation
import IOKit.hidsystem

@MainActor
public final class PermissionService {
    private nonisolated static let accessibilityPromptKey = "AXTrustedCheckOptionPrompt"

    public enum SettingsSection: Sendable {
        case inputMonitoring
        case accessibility
    }

    public init() {}

    public func currentSnapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            // Check the capability consumed by our IOHIDManager. A Quartz
            // event-tap preflight does not describe whether HID access is ready.
            inputMonitoringGranted: IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted,
            accessibilityGranted: AXIsProcessTrusted(),
            eventPostingGranted: CGPreflightPostEventAccess()
        )
    }

    /// Call only in direct response to a user interaction. macOS may present
    /// a privacy prompt or redirect the user to System Settings.
    @discardableResult
    public func requestInputMonitoring() -> PermissionSnapshot {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        return currentSnapshot()
    }

    /// Call only in direct response to a user interaction.
    @discardableResult
    public func requestAccessibility(prompt: Bool = true) -> PermissionSnapshot {
        if prompt {
            _ = AXIsProcessTrustedWithOptions([
                Self.accessibilityPromptKey: true,
            ] as CFDictionary)
        }
        return currentSnapshot()
    }

    /// Event-posting access is checked separately from Accessibility because
    /// either capability can be revoked while the application is running.
    /// Call only in direct response to a user interaction.
    @discardableResult
    public func requestEventPosting() -> PermissionSnapshot {
        _ = CGRequestPostEventAccess()
        return currentSnapshot()
    }

    @discardableResult
    public func openSystemSettings(_ section: SettingsSection) -> Bool {
        let destination: String
        switch section {
        case .inputMonitoring:
            destination = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        case .accessibility:
            destination = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        }

        guard let url = URL(string: destination) else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }
}
