import Foundation

/// The origin of a sample. A recording's origin is separate from its delivery mode.
public enum Provenance: String, Codable, Sendable {
    case mock = "MOCK"
    case replay = "REPLAY"
    case live = "LIVE"
}

/// Project-owned diagnostic contract, not a DJI wire format or API clone.
public struct TelemetryPacket: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let sessionID: String
    public let sequence: UInt64
    public let source: Provenance
    public let sourceTimestampUnixMilliseconds: Int64?
    public let altitudeRelativeMeters: Double?
    public let batteryPercent: Double?

    public init(
        schemaVersion: Int = 1, sessionID: String, sequence: UInt64,
        source: Provenance, sourceTimestampUnixMilliseconds: Int64? = nil,
        altitudeRelativeMeters: Double? = nil, batteryPercent: Double? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.sessionID = sessionID
        self.sequence = sequence
        self.source = source
        self.sourceTimestampUnixMilliseconds = sourceTimestampUnixMilliseconds
        self.altitudeRelativeMeters = altitudeRelativeMeters
        self.batteryPercent = batteryPercent
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, sessionID, sequence, source
        case sourceTimestampUnixMilliseconds, altitudeRelativeMeters, batteryPercent
    }

    // Emit missing observations as explicit nulls rather than invented zeros.
    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(sessionID, forKey: .sessionID)
        try values.encode(sequence, forKey: .sequence)
        try values.encode(source, forKey: .source)
        try values.encode(sourceTimestampUnixMilliseconds, forKey: .sourceTimestampUnixMilliseconds)
        try values.encode(altitudeRelativeMeters, forKey: .altitudeRelativeMeters)
        try values.encode(batteryPercent, forKey: .batteryPercent)
    }
}

public enum TelemetryError: String, Error, Sendable {
    case unsupportedSchema, invalidSession, wrongSession, nonIncreasingSequence
    case invalidClock, stale, invalidMeasurement, invalidSourceTimestamp
    case tooLarge, tooManyEvents, notSynthetic, sourceMismatch
}

/// `localAgeMilliseconds` is time since local receipt, not camera/aircraft age.
public struct ValidatedObservation: Equatable, Sendable {
    public let packet: TelemetryPacket
    public let delivery: Provenance
    public let localAgeMilliseconds: UInt64
}

/// Single-session, sequential validator. The caller supplies one monotonic clock.
/// It grants no command authority, even when the declared source is LIVE.
public struct TelemetrySession: Sendable {
    public let sessionID: String
    public let maxLocalAgeMilliseconds: UInt64
    public let delivery: Provenance
    private var lastSequence: UInt64?

    public init(
        sessionID: String, delivery: Provenance,
        maxLocalAgeMilliseconds: UInt64 = 1_000
    ) throws {
        guard !sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              sessionID.utf8.count <= 128 else { throw TelemetryError.invalidSession }
        self.sessionID = sessionID
        self.delivery = delivery
        self.maxLocalAgeMilliseconds = maxLocalAgeMilliseconds
    }

    public mutating func accept(
        _ packet: TelemetryPacket,
        receivedAtMilliseconds: UInt64,
        nowMilliseconds: UInt64
    ) throws -> ValidatedObservation {
        guard packet.schemaVersion == 1 else { throw TelemetryError.unsupportedSchema }
        guard packet.sessionID == sessionID else { throw TelemetryError.wrongSession }
        if let lastSequence, packet.sequence <= lastSequence {
            throw TelemetryError.nonIncreasingSequence
        }
        guard nowMilliseconds >= receivedAtMilliseconds else { throw TelemetryError.invalidClock }
        let age = nowMilliseconds - receivedAtMilliseconds
        guard age <= maxLocalAgeMilliseconds else { throw TelemetryError.stale }
        if let timestamp = packet.sourceTimestampUnixMilliseconds, timestamp < 0 {
            throw TelemetryError.invalidSourceTimestamp
        }
        if let altitude = packet.altitudeRelativeMeters, !altitude.isFinite {
            throw TelemetryError.invalidMeasurement
        }
        if let battery = packet.batteryPercent,
           !battery.isFinite || !(0...100).contains(battery) {
            throw TelemetryError.invalidMeasurement
        }
        lastSequence = packet.sequence
        return ValidatedObservation(packet: packet, delivery: delivery, localAgeMilliseconds: age)
    }
}

public struct ReplayEvent: Codable, Sendable {
    public let receivedAtMilliseconds: UInt64
    public let nowMilliseconds: UInt64
    public let packet: TelemetryPacket
}

/// Initial replay tool accepts only synthetic MOCK fixtures; no private captures.
public struct SyntheticReplay: Codable, Sendable {
    public static let maximumBytes = 262_144
    public static let maximumEvents = 256
    public let schemaVersion: Int
    public let synthetic: Bool
    public let sessionID: String
    public let events: [ReplayEvent]

    public static func decode(_ data: Data) throws -> SyntheticReplay {
        guard data.count <= maximumBytes else { throw TelemetryError.tooLarge }
        let fixture = try JSONDecoder().decode(Self.self, from: data)
        try fixture.checkEnvelope()
        return fixture
    }

    private func checkEnvelope() throws {
        guard schemaVersion == 1 else { throw TelemetryError.unsupportedSchema }
        guard synthetic else { throw TelemetryError.notSynthetic }
        guard events.count <= Self.maximumEvents else { throw TelemetryError.tooManyEvents }
        guard events.allSatisfy({ $0.packet.source == .mock }) else {
            throw TelemetryError.sourceMismatch
        }
    }

    public func validate() throws -> [ValidatedObservation] {
        try checkEnvelope()
        var session = try TelemetrySession(sessionID: sessionID, delivery: .replay)
        return try events.map {
            try session.accept($0.packet, receivedAtMilliseconds: $0.receivedAtMilliseconds,
                               nowMilliseconds: $0.nowMilliseconds)
        }
    }
}

public enum ResearchCapabilities {
    public static let nativeIOSTransportAvailable = false
    public static let aircraftCommandsAvailable = false
    public static let hardwareValidated = false
}
