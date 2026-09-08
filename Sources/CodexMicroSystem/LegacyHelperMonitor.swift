import AppKit
import Foundation

private final class LegacyMonitorResources {
    let workspace: NSWorkspace
    var notificationTokens: [NSObjectProtocol] = []
    var refreshTimer: Timer?

    init(workspace: NSWorkspace) {
        self.workspace = workspace
    }

    deinit {
        invalidate()
    }

    func invalidate() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        notificationTokens.forEach(workspace.notificationCenter.removeObserver)
        notificationTokens.removeAll()
    }
}

@MainActor
public final class LegacyHelperMonitor {
    public typealias ConflictHandler = @MainActor (LegacyHelperConflict?) -> Void

    public private(set) var conflict: LegacyHelperConflict?
    public var onConflictChanged: ConflictHandler?

    private let identity: LegacyHelperIdentity
    private let workspace: NSWorkspace
    private let resources: LegacyMonitorResources
    private var isMonitoring = false

    public init(
        identity: LegacyHelperIdentity = .default,
        workspace: NSWorkspace = .shared
    ) {
        self.identity = identity
        self.workspace = workspace
        resources = LegacyMonitorResources(workspace: workspace)
    }

    public func startMonitoring() {
        guard !isMonitoring else {
            refresh()
            return
        }
        isMonitoring = true

        let center = workspace.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ]
        resources.notificationTokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    _ = self?.refresh()
                }
            }
        }

        resources.refreshTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                _ = self?.refresh()
            }
        }
        refresh()
    }

    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        resources.invalidate()

        updateConflict(nil)
    }

    @discardableResult
    public func refresh() -> LegacyHelperConflict? {
        let detectedConflict = workspace.runningApplications
            .map(Self.descriptor(for:))
            .first(where: identity.matches)
            .map(LegacyHelperConflict.init(process:))
        updateConflict(detectedConflict)
        return detectedConflict
    }

    /// This method intentionally never runs automatically. It must be called
    /// only from an explicit user-facing recovery action.
    @discardableResult
    public func terminateConflictingHelper() -> Bool {
        guard let conflict,
              let application = workspace.runningApplications.first(where: {
                  $0.processIdentifier == conflict.process.processIdentifier
              }) else {
            refresh()
            return self.conflict == nil
        }

        let requested = application.terminate()
        if requested {
            refresh()
        }
        return requested
    }

    private func updateConflict(_ newValue: LegacyHelperConflict?) {
        guard conflict != newValue else { return }
        conflict = newValue
        onConflictChanged?(newValue)
    }

    private static func descriptor(for application: NSRunningApplication) -> LegacyProcessDescriptor {
        LegacyProcessDescriptor(
            processIdentifier: application.processIdentifier,
            bundleIdentifier: application.bundleIdentifier,
            executableName: application.executableURL?.lastPathComponent,
            executablePath: application.executableURL?.path,
            bundlePath: application.bundleURL?.path,
            localizedName: application.localizedName
        )
    }
}
