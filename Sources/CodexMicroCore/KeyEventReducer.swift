/// Debounces ordinary keys and merges ACT10/ACT11 into one wide-key control.
/// Keep one reducer per connected device and call `reset()` whenever its HID
/// lifecycle stops, disconnects, wakes, or reconnects.
public struct KeyEventReducer: Sendable {
    private var activeOrdinaryKeys: Set<RawPhysicalKey> = []
    private var activeWideKeySwitches: Set<RawPhysicalKey> = []

    public init() {}

    /// Returns a logical event only when a physical state transition changes
    /// the corresponding logical control. Repeated down/up reports are ignored.
    public mutating func reduce(_ event: HIDKeyEvent) -> LogicalKeyEvent? {
        if event.key == .act10 || event.key == .act11 {
            return reduceWideKey(event)
        }
        return reduceOrdinaryKey(event)
    }

    public mutating func reset() {
        activeOrdinaryKeys.removeAll(keepingCapacity: false)
        activeWideKeySwitches.removeAll(keepingCapacity: false)
    }

    private mutating func reduceOrdinaryKey(_ event: HIDKeyEvent) -> LogicalKeyEvent? {
        switch event.phase {
        case .down:
            guard activeOrdinaryKeys.insert(event.key).inserted else { return nil }
        case .up:
            guard activeOrdinaryKeys.remove(event.key) != nil else { return nil }
        }

        return LogicalKeyEvent(
            control: PhysicalControl(rawKey: event.key),
            phase: event.phase,
            sourceKey: event.key
        )
    }

    private mutating func reduceWideKey(_ event: HIDKeyEvent) -> LogicalKeyEvent? {
        switch event.phase {
        case .down:
            let wasIdle = activeWideKeySwitches.isEmpty
            guard activeWideKeySwitches.insert(event.key).inserted else { return nil }
            guard wasIdle else { return nil }
            return LogicalKeyEvent(
                control: .wideMicrophone,
                phase: .down,
                sourceKey: event.key
            )

        case .up:
            let wasActive = !activeWideKeySwitches.isEmpty
            guard activeWideKeySwitches.remove(event.key) != nil else { return nil }
            guard wasActive, activeWideKeySwitches.isEmpty else { return nil }
            return LogicalKeyEvent(
                control: .wideMicrophone,
                phase: .up,
                sourceKey: event.key
            )
        }
    }
}
