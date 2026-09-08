import CodexMicroSystem

/// A window-open request survives an active editor, but is consumed only once.
/// Permission polling updates the visible UI without creating new requests.
struct PermissionOnboardingRequest: Equatable {
    private(set) var isPending = false

    mutating func request(for permissions: PermissionSnapshot) {
        isPending = needsPermissions(permissions)
    }

    mutating func take(for permissions: PermissionSnapshot) -> Bool {
        defer { isPending = false }
        return isPending && needsPermissions(permissions)
    }

    private func needsPermissions(_ permissions: PermissionSnapshot) -> Bool {
        !permissions.inputMonitoringGranted || !permissions.canExecuteMappings
    }
}
