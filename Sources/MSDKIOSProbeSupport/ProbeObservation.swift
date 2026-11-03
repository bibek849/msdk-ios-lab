import Foundation

/// Cohort label fixed when a run is created; no observation can change it.
public enum ProbeCohort: String, Codable, Sendable {
    case cold = "COLD"
    case primed = "PRIMED"
    case unspecified = "UNSPECIFIED"
}

/// Why a run was stopped before its window elapsed. Budgets are diagnostic
/// limits chosen by this project, not properties of any accessory protocol.
public enum ProbeStopReason: String, Codable, Sendable, CaseIterable {
    case `operator` = "OPERATOR"
    case streamError = "STREAM_ERROR"
    case streamEnd = "STREAM_END"
    case eventBudget = "EVENT_BUDGET"
    case readBudget = "READ_BUDGET"
    case appBackground = "APP_BACKGROUND"
}

public enum ProbeStream: String, Codable, Sendable {
    case input = "INPUT"
    case output = "OUTPUT"
}

/// Labels for separately defined synthetic observations. They exercise this
/// model only; they describe no device, initialization or readiness mechanism.
public enum ProbeReadinessFact: String, Codable, Sendable, CaseIterable {
    case aircraftReady = "AIRCRAFT_READY"
    case initializationComplete = "INITIALIZATION_COMPLETE"
    case telemetryValid = "TELEMETRY_VALID"
}

/// Public-API-level facts a probe may observe. Project-owned diagnostic
/// contract (docs/PROBE_OBSERVATION_CONTRACT.md), not a DJI wire format.
public enum ProbeEvent: Equatable, Sendable {
    case accessoryVisible(accessoryID: UInt64)
    case protocolsAdvertised(accessoryID: UInt64, names: [String])
    case sessionCreated(sessionID: String, protocolName: String)
    case sessionCreationFailed(protocolName: String)
    case streamOpened(sessionID: String, stream: ProbeStream)
    case streamError(sessionID: String, stream: ProbeStream)
    case streamEnd(sessionID: String, stream: ProbeStream)
    case bytesAvailable(sessionID: String)
    case readCompleted(sessionID: String, byteCount: UInt64)
    case readFailed(sessionID: String)
    case writeAttempted(sessionID: String)
    case syntheticReadiness(fact: ProbeReadinessFact, value: Bool)
    case sessionClosed(sessionID: String)
    case accessoryDetached(accessoryID: UInt64)
    case runStopped(reason: ProbeStopReason)
}

/// One observation. `atMilliseconds` comes from the caller's monotonic clock.
public struct ProbeObservation: Codable, Equatable, Sendable {
    public let runID: String
    public let atMilliseconds: UInt64
    public let event: ProbeEvent

    public init(runID: String, atMilliseconds: UInt64, event: ProbeEvent) {
        self.runID = runID
        self.atMilliseconds = atMilliseconds
        self.event = event
    }

    enum Kind: String, Codable {
        case accessoryVisible = "ACCESSORY_VISIBLE"
        case protocolsAdvertised = "PROTOCOLS_ADVERTISED"
        case sessionCreated = "SESSION_CREATED"
        case sessionCreationFailed = "SESSION_CREATION_FAILED"
        case streamOpened = "STREAM_OPENED"
        case streamError = "STREAM_ERROR"
        case streamEnd = "STREAM_END"
        case bytesAvailable = "BYTES_AVAILABLE"
        case readCompleted = "READ_COMPLETED"
        case readFailed = "READ_FAILED"
        case writeAttempted = "WRITE_ATTEMPTED"
        case syntheticReadiness = "SYNTHETIC_READINESS"
        case sessionClosed = "SESSION_CLOSED"
        case accessoryDetached = "ACCESSORY_DETACHED"
        case runStopped = "RUN_STOPPED"
    }

    enum CodingKeys: String, CodingKey {
        case runID, atMilliseconds, kind
        case accessoryID, names, sessionID, protocolName, stream, byteCount, fact, value, reason
    }

    // A flat `kind` discriminator; unknown kinds, missing fields and
    // out-of-range numbers fail decoding. Extra fields are ignored.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        runID = try values.decode(String.self, forKey: .runID)
        atMilliseconds = try values.decode(UInt64.self, forKey: .atMilliseconds)
        func session() throws -> String { try values.decode(String.self, forKey: .sessionID) }
        func accessory() throws -> UInt64 { try values.decode(UInt64.self, forKey: .accessoryID) }
        func stream() throws -> ProbeStream { try values.decode(ProbeStream.self, forKey: .stream) }
        func protocolName() throws -> String { try values.decode(String.self, forKey: .protocolName) }
        switch try values.decode(Kind.self, forKey: .kind) {
        case .accessoryVisible: event = .accessoryVisible(accessoryID: try accessory())
        case .protocolsAdvertised:
            event = .protocolsAdvertised(accessoryID: try accessory(),
                                         names: try values.decode([String].self, forKey: .names))
        case .sessionCreated: event = .sessionCreated(sessionID: try session(), protocolName: try protocolName())
        case .sessionCreationFailed: event = .sessionCreationFailed(protocolName: try protocolName())
        case .streamOpened: event = .streamOpened(sessionID: try session(), stream: try stream())
        case .streamError: event = .streamError(sessionID: try session(), stream: try stream())
        case .streamEnd: event = .streamEnd(sessionID: try session(), stream: try stream())
        case .bytesAvailable: event = .bytesAvailable(sessionID: try session())
        case .readCompleted:
            event = .readCompleted(sessionID: try session(),
                                   byteCount: try values.decode(UInt64.self, forKey: .byteCount))
        case .readFailed: event = .readFailed(sessionID: try session())
        case .writeAttempted: event = .writeAttempted(sessionID: try session())
        case .syntheticReadiness:
            event = .syntheticReadiness(fact: try values.decode(ProbeReadinessFact.self, forKey: .fact),
                                        value: try values.decode(Bool.self, forKey: .value))
        case .sessionClosed: event = .sessionClosed(sessionID: try session())
        case .accessoryDetached: event = .accessoryDetached(accessoryID: try accessory())
        case .runStopped: event = .runStopped(reason: try values.decode(ProbeStopReason.self, forKey: .reason))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(runID, forKey: .runID)
        try values.encode(atMilliseconds, forKey: .atMilliseconds)
        switch event {
        case .accessoryVisible(let accessoryID):
            try values.encode(Kind.accessoryVisible, forKey: .kind)
            try values.encode(accessoryID, forKey: .accessoryID)
        case .protocolsAdvertised(let accessoryID, let names):
            try values.encode(Kind.protocolsAdvertised, forKey: .kind)
            try values.encode(accessoryID, forKey: .accessoryID)
            try values.encode(names, forKey: .names)
        case .sessionCreated(let sessionID, let protocolName):
            try values.encode(Kind.sessionCreated, forKey: .kind)
            try values.encode(sessionID, forKey: .sessionID)
            try values.encode(protocolName, forKey: .protocolName)
        case .sessionCreationFailed(let protocolName):
            try values.encode(Kind.sessionCreationFailed, forKey: .kind)
            try values.encode(protocolName, forKey: .protocolName)
        case .streamOpened(let sessionID, let stream):
            try values.encode(Kind.streamOpened, forKey: .kind)
            try values.encode(sessionID, forKey: .sessionID)
            try values.encode(stream, forKey: .stream)
        case .streamError(let sessionID, let stream):
            try values.encode(Kind.streamError, forKey: .kind)
            try values.encode(sessionID, forKey: .sessionID)
            try values.encode(stream, forKey: .stream)
        case .streamEnd(let sessionID, let stream):
            try values.encode(Kind.streamEnd, forKey: .kind)
            try values.encode(sessionID, forKey: .sessionID)
            try values.encode(stream, forKey: .stream)
        case .bytesAvailable(let sessionID):
            try values.encode(Kind.bytesAvailable, forKey: .kind)
            try values.encode(sessionID, forKey: .sessionID)
        case .readCompleted(let sessionID, let byteCount):
            try values.encode(Kind.readCompleted, forKey: .kind)
            try values.encode(sessionID, forKey: .sessionID)
            try values.encode(byteCount, forKey: .byteCount)
        case .readFailed(let sessionID):
            try values.encode(Kind.readFailed, forKey: .kind)
            try values.encode(sessionID, forKey: .sessionID)
        case .writeAttempted(let sessionID):
            try values.encode(Kind.writeAttempted, forKey: .kind)
            try values.encode(sessionID, forKey: .sessionID)
        case .syntheticReadiness(let fact, let value):
            try values.encode(Kind.syntheticReadiness, forKey: .kind)
            try values.encode(fact, forKey: .fact)
            try values.encode(value, forKey: .value)
        case .sessionClosed(let sessionID):
            try values.encode(Kind.sessionClosed, forKey: .kind)
            try values.encode(sessionID, forKey: .sessionID)
        case .accessoryDetached(let accessoryID):
            try values.encode(Kind.accessoryDetached, forKey: .kind)
            try values.encode(accessoryID, forKey: .accessoryID)
        case .runStopped(let reason):
            try values.encode(Kind.runStopped, forKey: .kind)
            try values.encode(reason, forKey: .reason)
        }
    }
}
