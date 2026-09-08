@preconcurrency import AppKit
import ApplicationServices
import Combine
import CodexMicroCore

@MainActor
public final class ShortcutRecordingService: ObservableObject {
    public enum Failure: Equatable, Sendable { case permissions, unavailable, interrupted, busy }
    public enum State: Equatable, Sendable {
        case idle, waitingForRelease, recording, releasing, failed(Failure)
    }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var preview: KeyStrokeDefinition?
    public var onCapture: ((KeyStrokeDefinition) -> Void)?
    public var onSessionChanged: ((Bool) -> Void)?

    // Retains a cancelled session just long enough to consume the release of
    // keys whose downs it swallowed, even if the sheet has been dismissed.
    private static var activeSession: ShortcutRecordingService?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var capture = ShortcutCapture()
    private var modifierKeys: Set<ModifierKey> = []
    private var initialKeys: Set<UInt16> = []
    private var observers: [NSObjectProtocol] = []
    private var watchdog: Timer?
    private var cancellationDeadline: Date?
    private var endingFailure: Failure?
    private var completionScheduled = false

    public init() {}

    public var isRecording: Bool { tap != nil }

    public func start() {
        guard tap == nil else { return }
        guard Self.activeSession == nil else { state = .failed(.busy); return }
        guard AXIsProcessTrusted(), CGPreflightListenEventAccess(), CGPreflightPostEventAccess() else {
            state = .failed(.permissions)
            return
        }
        capture = ShortcutCapture()
        completionScheduled = false
        preview = nil
        endingFailure = nil
        cancellationDeadline = nil
        initialKeys = Set((0..<128).compactMap { code -> UInt16? in
            CGEventSource.keyState(.combinedSessionState, key: CGKeyCode(code)) ? UInt16(code) : nil
        })
        modifierKeys = Set(initialKeys.compactMap(ModifierKey.init(rawValue:)))

        let mask = [CGEventType.keyDown, .keyUp, .flagsChanged].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return MainActor.assumeIsolated {
                    Unmanaged<ShortcutRecordingService>.fromOpaque(context).takeUnretainedValue().receive(type, event)
                }
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { state = .failed(.unavailable); return }

        tap = created
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        guard let source else { tearDown(); state = .failed(.unavailable); return }
        Self.activeSession = self
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        state = initialKeys.isEmpty ? .recording : .waitingForRelease
        onSessionChanged?(true)

        for name in [NSApplication.didResignActiveNotification, NSApplication.willTerminateNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.cancel(failure: .interrupted) }
            })
        }
        if let window = NSApp.keyWindow {
            observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.cancel(failure: .interrupted) }
            })
        }
        let watchdog = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let tap = self.tap else { return }
                if !CGEvent.tapIsEnabled(tap: tap) || !AXIsProcessTrusted()
                    || !CGPreflightListenEventAccess() || !CGPreflightPostEventAccess() {
                    self.tearDown()
                    self.state = .failed(.interrupted)
                } else if let deadline = self.cancellationDeadline, deadline <= .now {
                    self.finish()
                }
            }
        }
        self.watchdog = watchdog
        RunLoop.main.add(watchdog, forMode: .common)
    }

    public func cancel(failure: Failure? = nil) {
        guard tap != nil else { state = .idle; return }
        endingFailure = failure
        capture.cancel()
        if capture.pressedKeys.isEmpty { finish() }
        else {
            state = .releasing
            cancellationDeadline = .now.addingTimeInterval(2)
        }
    }

    private func receive(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            tearDown()
            state = .failed(.interrupted)
            return Unmanaged.passUnretained(event)
        }
        if completionScheduled { return Unmanaged.passUnretained(event) }
        let code = UInt16(clamping: event.getIntegerValueField(.keyboardEventKeycode))
        let phase: KeyPhase
        if type == .flagsChanged, let key = ModifierKey(rawValue: code) {
            let sideMask = key.deviceFlag
            let hasSide = sideMask != 0 && event.flags.rawValue & sideMask != 0
            let genericFlags = key.eventFlags.rawValue & ~UInt64(0xFFFF)
            let hasGeneric = event.flags.rawValue & genericFlags != 0
            // Real keyboards carry side flags. The fallback also accepts event
            // sources which only provide the device-independent modifier bit.
            let hasAnySide = ModifierKey.allCases.filter { $0.modifier == key.modifier }
                .contains { $0.deviceFlag != 0 && event.flags.rawValue & $0.deviceFlag != 0 }
            let down = hasSide || (hasGeneric && !hasAnySide && !modifierKeys.contains(key))
            phase = down ? .down : .up
            if down { modifierKeys.insert(key) } else { modifierKeys.remove(key) }
        } else if type == .keyDown || type == .keyUp {
            phase = type == .keyDown ? .down : .up
            if let key = ModifierKey(rawValue: code) {
                if phase == .down { modifierKeys.insert(key) } else { modifierKeys.remove(key) }
            } else {
                // Some injected/input-method events carry flags without separate
                // flagsChanged events. Keep their combination intact as well.
                for fallback in ModifierKey.defaultKeys {
                    let family = fallback.eventFlags.rawValue & ~UInt64(0xFFFF)
                    if event.flags.rawValue & family == 0 {
                        modifierKeys = modifierKeys.filter { $0.modifier != fallback.modifier }
                    } else if !modifierKeys.contains(where: { $0.modifier == fallback.modifier }) {
                        let side = ModifierKey.allCases.first {
                            $0.modifier == fallback.modifier && $0.deviceFlag != 0 && event.flags.rawValue & $0.deviceFlag != 0
                        }
                        modifierKeys.insert(side ?? fallback)
                    }
                }
            }
        } else { return Unmanaged.passUnretained(event) }

        if !initialKeys.isEmpty {
            if phase == .down { initialKeys.insert(code) } else { initialKeys.remove(code) }
            if initialKeys.isEmpty { state = .recording }
            return Unmanaged.passUnretained(event)
        }
        // While cancelling, consume only releases/repeats belonging to this
        // session; unrelated new input must continue to work immediately.
        if capture.isCancelled && !capture.pressedKeys.contains(code) {
            return Unmanaged.passUnretained(event)
        }
        capture.receive(keyCode: code, phase: phase, modifiers: modifierKeys)
        preview = capture.candidate
        if capture.isFinished {
            completionScheduled = true
            // Finish after this callback has returned nil for the final up.
            DispatchQueue.main.async { [weak self] in self?.finish() }
        }
        return nil
    }

    private func finish() {
        guard tap != nil else { return }
        let result = capture.isCancelled ? nil : capture.candidate
        let failure = endingFailure
        tearDown()
        state = failure.map(State.failed) ?? .idle
        if let result { onCapture?(result) }
    }

    private func tearDown() {
        watchdog?.invalidate()
        watchdog = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
        initialKeys.removeAll()
        modifierKeys.removeAll()
        cancellationDeadline = nil
        if Self.activeSession === self { Self.activeSession = nil }
        onSessionChanged?(false)
    }
}
