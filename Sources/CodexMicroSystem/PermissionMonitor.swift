import Foundation

/// Observes capabilities available to this process without presenting prompts.
/// Common run-loop modes keep checks active in menus, sheets and tracking loops,
/// including while System Settings is in the foreground. A lifecycle refresh
/// also checks immediately after activation or wake.
@MainActor
public final class PermissionMonitor {
    public var onSnapshot: ((PermissionSnapshot) -> Void)?

    private let interval: TimeInterval
    private let readSnapshot: () -> PermissionSnapshot
    private var timer: Timer?
    private var generation: UInt64 = 0

    public init(
        interval: TimeInterval = 1,
        readSnapshot: @escaping () -> PermissionSnapshot
    ) {
        precondition(interval > 0)
        self.interval = interval
        self.readSnapshot = readSnapshot
    }

    isolated deinit {
        timer?.invalidate()
    }

    public var isRunning: Bool { timer != nil }

    public func start() {
        guard timer == nil else { return }
        generation &+= 1
        let generation = generation
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.generation == generation else { return }
                self.refresh()
            }
        }
        timer.tolerance = min(interval * 0.1, 0.1)
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        refresh()
    }

    public func refresh() {
        guard isRunning else { return }
        onSnapshot?(readSnapshot())
    }

    public func stop() {
        generation &+= 1
        timer?.invalidate()
        timer = nil
    }
}
