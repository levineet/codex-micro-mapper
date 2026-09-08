import CodexMicroCore
import Foundation
@preconcurrency import IOKit.hid

private enum HIDConstants {
    static let vendorID = 0x303A
    static let productID = 0x8360
    static let reportID: UInt32 = HIDFrameDecoder.vendorReportID
}

public enum CodexMicroHIDServiceError: LocalizedError, Sendable, Equatable {
    case unableToCreateManager
    case unableToOpenManager(code: Int32)

    public var errorDescription: String? {
        switch self {
        case .unableToCreateManager:
            return "Unable to create the Codex Micro HID manager."
        case let .unableToOpenManager(code):
            return String(
                format: "Unable to open the Codex Micro HID manager (0x%08X).",
                UInt32(bitPattern: code)
            )
        }
    }
}

/// Owns the complete IOHID lifecycle for one mapper process.
///
/// The manager is scheduled on the main run loop. This makes callback teardown
/// deterministic: `stop()` unregisters every callback and unschedules/closes
/// the manager while no other callback can execute concurrently. The
/// manager-level report callback is used deliberately, so no caller-owned
/// unsafe report buffer survives a stop. Decoder and press-edge buffers are
/// reset on every connection boundary.
public final class CodexMicroHIDService {
    public nonisolated static let vendorID = HIDConstants.vendorID
    public nonisolated static let productID = HIDConstants.productID
    public nonisolated static let reportID = HIDConstants.reportID

    public typealias ConnectionHandler = (CodexMicroHIDConnectionState) -> Void
    public typealias RawEventHandler = (HIDKeyEvent) -> Void
    public typealias LogicalEventHandler = (LogicalKeyEvent) -> Void

    public private(set) var connectionState: CodexMicroHIDConnectionState = .stopped
    public private(set) var lastRawEvent: HIDKeyEvent?
    public private(set) var lastLogicalEvent: LogicalKeyEvent?

    public var onConnectionChanged: ConnectionHandler?
    public var onRawEvent: RawEventHandler?
    public var onLogicalEvent: LogicalEventHandler?

    private var manager: IOHIDManager?
    private var decoder = HIDFrameDecoder(reportID: HIDConstants.reportID)
    private var reducer = KeyEventReducer()
    private var connectedDevices: [UInt64: CodexMicroDeviceDescriptor] = [:]

    public init() {}

    deinit {
        if let manager {
            Self.tearDown(manager)
        }
    }

    public var isRunning: Bool {
        manager != nil
    }

    public func start() throws {
        guard manager == nil else { return }

        let hidManager = IOHIDManagerCreate(
            kCFAllocatorDefault,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )

        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: Self.vendorID,
            kIOHIDProductIDKey as String: Self.productID,
        ]
        IOHIDManagerSetDeviceMatching(hidManager, matching as CFDictionary)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(
            hidManager,
            codexMicroDeviceMatchedCallback,
            context
        )
        IOHIDManagerRegisterDeviceRemovalCallback(
            hidManager,
            codexMicroDeviceRemovedCallback,
            context
        )
        IOHIDManagerRegisterInputReportCallback(
            hidManager,
            codexMicroInputReportCallback,
            context
        )
        IOHIDManagerScheduleWithRunLoop(
            hidManager,
            CFRunLoopGetMain(),
            CFRunLoopMode.defaultMode.rawValue
        )

        let result = IOHIDManagerOpen(
            hidManager,
            IOOptionBits(kIOHIDOptionsTypeNone)
        )
        guard result == kIOReturnSuccess else {
            Self.tearDown(hidManager)
            let error = CodexMicroHIDServiceError.unableToOpenManager(code: result)
            publishConnectionState(.failed(error.localizedDescription))
            throw error
        }

        manager = hidManager
        resetEventState()
        publishConnectionState(.listening)
    }

    public func stop() {
        guard let manager else {
            resetEventState()
            publishConnectionState(.stopped)
            return
        }

        // Clear our strong reference before teardown so a re-entrant stop is a
        // no-op. All callbacks share the main run loop, so none can race this.
        self.manager = nil
        Self.tearDown(manager)
        connectedDevices.removeAll(keepingCapacity: false)
        resetEventState()
        publishConnectionState(.stopped)
    }

    /// Use after wake or any external lifecycle boundary where an up event may
    /// have been lost. This does not close the HID manager.
    public func resetPressState() {
        resetEventState()
    }

    fileprivate func deviceMatched(_ device: IOHIDDevice) {
        guard manager != nil else { return }

        // A reconnect may follow a lost release report. Never carry press-edge
        // state from the previous transport session.
        resetEventState()

        let descriptor = Self.descriptor(for: device)
        let key = descriptor.registryEntryID ?? Self.pointerIdentifier(for: device)
        connectedDevices[key] = descriptor
        publishConnectionState(.connected(descriptor))
    }

    fileprivate func deviceRemoved(_ device: IOHIDDevice) {
        guard manager != nil else { return }

        let descriptor = Self.descriptor(for: device)
        let key = descriptor.registryEntryID ?? Self.pointerIdentifier(for: device)
        connectedDevices.removeValue(forKey: key)
        resetEventState()

        if let remaining = connectedDevices.values.first {
            publishConnectionState(.connected(remaining))
        } else {
            publishConnectionState(.listening)
        }
    }

    fileprivate func receivedReport(
        result: IOReturn,
        reportID: UInt32,
        report: UnsafeMutablePointer<UInt8>?,
        length: CFIndex
    ) {
        guard manager != nil,
              result == kIOReturnSuccess,
              reportID == Self.reportID,
              let report,
              length > 0 else {
            return
        }

        let bytes = Array(UnsafeBufferPointer(start: report, count: length))
        for event in decoder.receive(reportID: reportID, bytes: bytes) {
            lastRawEvent = event
            onRawEvent?(event)

            if let logicalEvent = reducer.reduce(event) {
                lastLogicalEvent = logicalEvent
                onLogicalEvent?(logicalEvent)
            }
        }
    }

    private func resetEventState() {
        decoder.reset()
        reducer.reset()
        lastRawEvent = nil
        lastLogicalEvent = nil
    }

    private func publishConnectionState(_ state: CodexMicroHIDConnectionState) {
        guard connectionState != state else { return }
        connectionState = state
        onConnectionChanged?(state)
    }

    private nonisolated static func tearDown(_ manager: IOHIDManager) {
        IOHIDManagerRegisterInputReportCallback(manager, nil, nil)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(
            manager,
            CFRunLoopGetMain(),
            CFRunLoopMode.defaultMode.rawValue
        )
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    private nonisolated static func descriptor(
        for device: IOHIDDevice
    ) -> CodexMicroDeviceDescriptor {
        let vendorID = (property(device, key: kIOHIDVendorIDKey) as? NSNumber)?.intValue
            ?? HIDConstants.vendorID
        let productID = (property(device, key: kIOHIDProductIDKey) as? NSNumber)?.intValue
            ?? HIDConstants.productID
        let productName = property(device, key: kIOHIDProductKey) as? String
            ?? "Codex Micro"
        let transport = property(device, key: kIOHIDTransportKey) as? String
            ?? "Unknown transport"

        var registryEntryID: UInt64 = 0
        let registryResult = IORegistryEntryGetRegistryEntryID(
            IOHIDDeviceGetService(device),
            &registryEntryID
        )

        return CodexMicroDeviceDescriptor(
            productName: productName,
            transport: transport,
            vendorID: vendorID,
            productID: productID,
            registryEntryID: registryResult == kIOReturnSuccess ? registryEntryID : nil
        )
    }

    private nonisolated static func property(
        _ device: IOHIDDevice,
        key: String
    ) -> Any? {
        IOHIDDeviceGetProperty(device, key as CFString)
    }

    private nonisolated static func pointerIdentifier(for device: IOHIDDevice) -> UInt64 {
        UInt64(UInt(bitPattern: Unmanaged.passUnretained(device).toOpaque()))
    }
}

private let codexMicroDeviceMatchedCallback: IOHIDDeviceCallback = {
    context, result, _, device in
    guard result == kIOReturnSuccess, let context else { return }
    Unmanaged<CodexMicroHIDService>
        .fromOpaque(context)
        .takeUnretainedValue()
        .deviceMatched(device)
}

private let codexMicroDeviceRemovedCallback: IOHIDDeviceCallback = {
    context, _, _, device in
    guard let context else { return }
    Unmanaged<CodexMicroHIDService>
        .fromOpaque(context)
        .takeUnretainedValue()
        .deviceRemoved(device)
}

private let codexMicroInputReportCallback: IOHIDReportCallback = {
    context, result, _, _, reportID, report, reportLength in
    guard let context else { return }
    Unmanaged<CodexMicroHIDService>
        .fromOpaque(context)
        .takeUnretainedValue()
        .receivedReport(
            result: result,
            reportID: reportID,
            report: report,
            length: reportLength
        )
}
