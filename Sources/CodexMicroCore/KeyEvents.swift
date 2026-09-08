import Foundation

/// The identifier reported by Codex Micro before any logical controls are
/// coalesced. Unknown identifiers are deliberately preserved so a future
/// learning UI can display new firmware keys without a Core update.
public struct RawPhysicalKey: RawRepresentable, Hashable, Sendable, Comparable,
    Codable, CustomStringConvertible
{
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String { rawValue }

    public static let act06 = Self(rawValue: "ACT06")
    public static let act07 = Self(rawValue: "ACT07")
    public static let act08 = Self(rawValue: "ACT08")
    public static let act09 = Self(rawValue: "ACT09")
    public static let act10 = Self(rawValue: "ACT10")
    public static let act11 = Self(rawValue: "ACT11")
    public static let act12 = Self(rawValue: "ACT12")
}

/// A user-mappable control. ACT10 and ACT11 are two switches under one wide
/// physical key, so they intentionally share one logical control.
public enum PhysicalControl: Hashable, Sendable, Codable, Identifiable {
    case key(RawPhysicalKey)
    case wideMicrophone

    public static let act06 = Self.key(.act06)
    public static let act07 = Self.key(.act07)
    public static let act08 = Self.key(.act08)
    public static let act09 = Self.key(.act09)
    public static let act12 = Self.key(.act12)

    public var id: String {
        switch self {
        case .key(let key):
            key.rawValue
        case .wideMicrophone:
            "ACT10+ACT11"
        }
    }

    public var rawKeys: [RawPhysicalKey] {
        switch self {
        case .key(let key):
            [key]
        case .wideMicrophone:
            [.act10, .act11]
        }
    }

    public init(rawKey: RawPhysicalKey) {
        if rawKey == .act10 || rawKey == .act11 {
            self = .wideMicrophone
        } else {
            self = .key(rawKey)
        }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let identifier = try container.decode(String.self)
        if identifier == "ACT10+ACT11" {
            self = .wideMicrophone
        } else {
            self = .key(RawPhysicalKey(rawValue: identifier))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(id)
    }
}

public enum KeyPhase: String, Codable, Equatable, Sendable {
    case down
    case up
}

/// A decoded event exactly as reported by one physical switch.
public struct HIDKeyEvent: Codable, Equatable, Sendable {
    public var key: RawPhysicalKey
    public var phase: KeyPhase
    public var agent: String?

    public init(key: RawPhysicalKey, phase: KeyPhase, agent: String? = nil) {
        self.key = key
        self.phase = phase
        self.agent = agent
    }

    public init(key: RawPhysicalKey, isPressed: Bool, agent: String? = nil) {
        self.init(key: key, phase: isPressed ? .down : .up, agent: agent)
    }

    public var isPressed: Bool { phase == .down }
}

/// A debounced event ready for mapping lookup.
public struct LogicalKeyEvent: Codable, Equatable, Sendable {
    public var control: PhysicalControl
    public var phase: KeyPhase
    public var sourceKey: RawPhysicalKey

    public init(
        control: PhysicalControl,
        phase: KeyPhase,
        sourceKey: RawPhysicalKey
    ) {
        self.control = control
        self.phase = phase
        self.sourceKey = sourceKey
    }

    public var isPressed: Bool { phase == .down }
}
