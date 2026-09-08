import Foundation

/// Decodes Codex Micro's channel-framed, newline-delimited vendor messages.
///
/// Each report contains an optional report-ID byte, a channel byte, a payload
/// length byte, and a UTF-8 JSON fragment. Buffers are independent per channel
/// and cannot exceed 64 KiB. After an overflow, that channel is ignored until
/// its next newline so a truncated JSON tail can never be interpreted as a new
/// command.
public struct HIDFrameDecoder: Sendable {
    public static let vendorReportID: UInt32 = 6
    public static let maximumBufferedBytesPerChannel = 64 * 1024

    private let acceptedReportID: UInt32
    private var channelBuffers: [UInt8: [UInt8]] = [:]
    private var channelsDiscardingOversizedLine: Set<UInt8> = []

    public private(set) var discardedOversizedLineCount = 0

    public init(reportID: UInt32 = Self.vendorReportID) {
        acceptedReportID = reportID
    }

    /// Feeds one IOHID report and returns every complete key event it contains.
    /// Reports for other report IDs and malformed/non-key JSON lines are ignored.
    public mutating func receive(reportID: UInt32, bytes: [UInt8]) -> [HIDKeyEvent] {
        guard reportID == acceptedReportID else { return [] }

        // Some transports include the report ID in byte zero while IOHID can
        // also provide it solely through the reportID callback parameter.
        let payloadOffset = bytes.first == UInt8(truncatingIfNeeded: acceptedReportID) ? 1 : 0
        guard bytes.count >= payloadOffset + 2 else { return [] }

        let channel = bytes[payloadOffset]
        let availablePayloadCount = bytes.count - payloadOffset - 2
        let declaredPayloadCount = Int(bytes[payloadOffset + 1])
        let payloadCount = min(declaredPayloadCount, availablePayloadCount)
        guard payloadCount > 0 else { return [] }

        let payloadStart = payloadOffset + 2
        let fragment = Array(bytes[payloadStart..<(payloadStart + payloadCount)])
        return consume(fragment, on: channel)
    }

    /// Clears all framing state, for example on disconnect or reconnect.
    public mutating func reset() {
        channelBuffers.removeAll(keepingCapacity: false)
        channelsDiscardingOversizedLine.removeAll(keepingCapacity: false)
    }

    public func bufferedByteCount(for channel: UInt8) -> Int {
        channelBuffers[channel]?.count ?? 0
    }

    public var totalBufferedByteCount: Int {
        channelBuffers.values.reduce(into: 0) { $0 += $1.count }
    }

    private mutating func consume(_ fragment: [UInt8], on channel: UInt8) -> [HIDKeyEvent] {
        var remaining = fragment[...]

        if channelsDiscardingOversizedLine.contains(channel) {
            guard let delimiter = remaining.firstIndex(where: Self.isNewline) else {
                return []
            }
            remaining = remaining[remaining.index(after: delimiter)...]
            channelsDiscardingOversizedLine.remove(channel)
        }

        var buffer = channelBuffers[channel, default: []]
        if buffer.count + remaining.count > Self.maximumBufferedBytesPerChannel {
            buffer.removeAll(keepingCapacity: false)
            discardedOversizedLineCount += 1

            if let delimiter = remaining.firstIndex(where: Self.isNewline) {
                remaining = remaining[remaining.index(after: delimiter)...]
            } else {
                channelsDiscardingOversizedLine.insert(channel)
                channelBuffers[channel] = buffer
                return []
            }
        }

        buffer.append(contentsOf: remaining)
        let events = Self.drainCompleteLines(from: &buffer)
        channelBuffers[channel] = buffer
        return events
    }

    private static func drainCompleteLines(from buffer: inout [UInt8]) -> [HIDKeyEvent] {
        var events: [HIDKeyEvent] = []

        while let delimiter = buffer.firstIndex(where: isNewline) {
            let line = Array(buffer[..<delimiter])
            var consumedThrough = delimiter

            // Treat CRLF as one delimiter when both bytes are already present.
            if buffer[delimiter] == 0x0D {
                let next = buffer.index(after: delimiter)
                if next < buffer.endIndex, buffer[next] == 0x0A {
                    consumedThrough = next
                }
            }
            buffer.removeSubrange(...consumedThrough)

            if let event = decodeJSONLine(line) {
                events.append(event)
            }
        }

        return events
    }

    private static func decodeJSONLine(_ bytes: [UInt8]) -> HIDKeyEvent? {
        let line = String(decoding: bytes, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty,
              let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any]
        else {
            return nil
        }

        let method = (dictionary["method"] ?? dictionary["m"]) as? String
        guard method == "v.oai.hid",
              let parameters = (dictionary["params"] ?? dictionary["p"]) as? [String: Any],
              let keyString = parameters["k"] as? String,
              !keyString.isEmpty,
              let phase = keyPhase(from: parameters["act"])
        else {
            return nil
        }

        return HIDKeyEvent(
            key: RawPhysicalKey(rawValue: keyString),
            phase: phase,
            agent: parameters["ag"] as? String
        )
    }

    private static func keyPhase(from value: Any?) -> KeyPhase? {
        if let boolean = value as? Bool {
            return boolean ? .down : .up
        }
        if let number = value as? NSNumber {
            return number.intValue == 0 ? .up : .down
        }
        return nil
    }

    private static func isNewline(_ byte: UInt8) -> Bool {
        byte == 0x0A || byte == 0x0D
    }
}
