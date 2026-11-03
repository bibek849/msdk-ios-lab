import Foundation
import MSDKIOSCore

public enum ProbeStreamState: String, Sendable {
    case notRequested = "NOT_REQUESTED"
    case open = "OPEN"
    case error = "ERROR"
    case end = "END"
}

/// Unknown unless a separately defined synthetic observation reports it.
/// Session, stream, read and write events never set it.
public enum SyntheticReadiness: Equatable, Sendable {
    case unknown
    case syntheticallyReported(Bool)
}

public enum ProbeEndReason: String, Sendable {
    case sessionClosed = "SESSION_CLOSED"
    case accessoryDetached = "ACCESSORY_DETACHED"
    case operatorStopped = "OPERATOR_STOPPED"
    case windowElapsed = "WINDOW_ELAPSED"
}

/// H1 stop-condition markers. Recording one changes no other fact.
public enum ProbePolicyFlag: String, Sendable, CaseIterable {
    case outputStreamActivity = "OUTPUT_STREAM_ACTIVITY"
    case writeAttemptBlocked = "WRITE_ATTEMPT_BLOCKED"
}

public enum ProbeError: String, Error, Sendable {
    case invalidRun, invalidWindow, invalidSession, invalidProtocolList
    case wrongRun, runEnded, beforeStart, outOfOrder, afterWindow
    case accessoryNotVisible, accessoryAlreadyVisible, differentAccessory
    case protocolsNotObserved, protocolNotAdvertised
    case sessionAlreadyCreated, noSession, wrongSession
    case streamNotOpenable, streamNotOpen, streamFinished, inputNotOpen
    case overflow, syntheticObservationNotAllowed
    case unsupportedSchema, notSynthetic, sourceMismatch, tooLarge, tooManyEvents
}

/// Independent facts for one run. Only counts, identifiers and times are kept.
public struct ProbeRunState: Equatable, Sendable {
    public let runID: String
    public let cohort: ProbeCohort
    public let origin: Provenance
    public let delivery: Provenance
    public let startedAtMilliseconds: UInt64
    public let windowEndMilliseconds: UInt64
    public fileprivate(set) var lastAcceptedAtMilliseconds: UInt64?
    public fileprivate(set) var accessoryID: UInt64?
    public fileprivate(set) var accessoryVisibleAtMilliseconds: UInt64?
    public fileprivate(set) var advertisedProtocols: [String]?
    public fileprivate(set) var sessionID: String?
    public fileprivate(set) var sessionProtocol: String?
    public fileprivate(set) var sessionCreatedAtMilliseconds: UInt64?
    public fileprivate(set) var sessionCreationFailures = 0
    public fileprivate(set) var inputStream = ProbeStreamState.notRequested
    public fileprivate(set) var outputStream = ProbeStreamState.notRequested
    public fileprivate(set) var bytesAvailableEvents = 0
    public fileprivate(set) var firstSuccessfulReadAtMilliseconds: UInt64?
    public fileprivate(set) var successfulReads = 0
    public fileprivate(set) var bytesRead: UInt64 = 0
    public fileprivate(set) var zeroByteReads = 0
    public fileprivate(set) var failedReads = 0
    public fileprivate(set) var blockedWriteAttempts = 0
    public fileprivate(set) var policyFlags: Set<ProbePolicyFlag> = []
    public fileprivate(set) var aircraftReady = SyntheticReadiness.unknown
    public fileprivate(set) var initializationComplete = SyntheticReadiness.unknown
    public fileprivate(set) var telemetryValid = SyntheticReadiness.unknown
    public fileprivate(set) var endReason: ProbeEndReason?
    public fileprivate(set) var endedAtMilliseconds: UInt64?

    fileprivate init(runID: String, cohort: ProbeCohort, origin: Provenance, delivery: Provenance,
                     startedAtMilliseconds: UInt64, windowEndMilliseconds: UInt64) {
        self.runID = runID
        self.cohort = cohort
        self.origin = origin
        self.delivery = delivery
        self.startedAtMilliseconds = startedAtMilliseconds
        self.windowEndMilliseconds = windowEndMilliseconds
    }
}

/// Single-run reducer. A rejected observation leaves `state` unchanged. It has
/// no transmit path, performs no accessory or stream operation and grants no
/// authority; `ResearchCapabilities` is untouched.
public struct ProbeRun: Sendable {
    public static let maximumWindowMilliseconds: UInt64 = 60_000
    public static let maximumIdentifierBytes = 128
    public static let maximumProtocols = 32
    public private(set) var state: ProbeRunState

    public init(runID: String, cohort: ProbeCohort, origin: Provenance, delivery: Provenance,
                startedAtMilliseconds: UInt64, windowMilliseconds: UInt64) throws {
        guard Self.isValidIdentifier(runID) else { throw ProbeError.invalidRun }
        guard (1...Self.maximumWindowMilliseconds).contains(windowMilliseconds) else {
            throw ProbeError.invalidWindow
        }
        let (windowEnd, overflow) = startedAtMilliseconds.addingReportingOverflow(windowMilliseconds)
        guard !overflow else { throw ProbeError.invalidWindow }
        state = ProbeRunState(runID: runID, cohort: cohort, origin: origin, delivery: delivery,
                              startedAtMilliseconds: startedAtMilliseconds, windowEndMilliseconds: windowEnd)
    }

    public mutating func apply(_ observation: ProbeObservation) throws {
        var next = state
        try Self.reduce(&next, observation)
        state = next
    }

    /// Ends an open run at exactly the window end; does nothing once ended.
    public mutating func expireWindow() {
        guard state.endReason == nil else { return }
        state.endReason = .windowElapsed
        state.endedAtMilliseconds = state.windowEndMilliseconds
    }

    private static func reduce(_ s: inout ProbeRunState, _ observation: ProbeObservation) throws {
        // Identity, then terminal state, then time, then the event's own rules.
        guard observation.runID == s.runID else { throw ProbeError.wrongRun }
        guard s.endReason == nil else { throw ProbeError.runEnded }
        let at = observation.atMilliseconds
        guard at >= s.startedAtMilliseconds else { throw ProbeError.beforeStart }
        if let last = s.lastAcceptedAtMilliseconds, at < last { throw ProbeError.outOfOrder }
        guard at <= s.windowEndMilliseconds else { throw ProbeError.afterWindow }

        switch observation.event {
        case .accessoryVisible(let accessoryID):
            if let existing = s.accessoryID {
                throw existing == accessoryID ? ProbeError.accessoryAlreadyVisible : ProbeError.differentAccessory
            }
            s.accessoryID = accessoryID
            s.accessoryVisibleAtMilliseconds = at
        case .protocolsAdvertised(let accessoryID, let names):
            try requireAccessory(s, accessoryID)
            guard isValidProtocolList(names) else { throw ProbeError.invalidProtocolList }
            s.advertisedProtocols = names
        case .sessionCreated(let sessionID, let protocolName):
            guard s.sessionID == nil else { throw ProbeError.sessionAlreadyCreated }
            try requireAdvertised(s, protocolName)
            guard isValidIdentifier(sessionID) else { throw ProbeError.invalidSession }
            s.sessionID = sessionID
            s.sessionProtocol = protocolName
            s.sessionCreatedAtMilliseconds = at
        case .sessionCreationFailed(let protocolName):
            guard s.sessionID == nil else { throw ProbeError.sessionAlreadyCreated }
            try requireAdvertised(s, protocolName)
            s.sessionCreationFailures += 1
        case .streamOpened(let sessionID, let stream):
            try requireSession(s, sessionID)
            switch streamState(s, stream) {
            case .notRequested: setStream(&s, stream, .open)
            case .open: throw ProbeError.streamNotOpenable
            case .error, .end: throw ProbeError.streamFinished
            }
        case .streamError(let sessionID, let stream):
            try requireSession(s, sessionID)
            switch streamState(s, stream) {
            case .notRequested, .open: setStream(&s, stream, .error)
            case .error, .end: throw ProbeError.streamFinished
            }
        case .streamEnd(let sessionID, let stream):
            try requireSession(s, sessionID)
            switch streamState(s, stream) {
            case .open: setStream(&s, stream, .end)
            case .notRequested: throw ProbeError.streamNotOpen
            case .error, .end: throw ProbeError.streamFinished
            }
        case .bytesAvailable(let sessionID):
            // Availability is not a read: it never sets a first-input time.
            try requireOpenInput(s, sessionID)
            s.bytesAvailableEvents += 1
        case .readCompleted(let sessionID, let byteCount):
            try requireOpenInput(s, sessionID)
            if byteCount == 0 {
                s.zeroByteReads += 1
            } else {
                let (total, overflow) = s.bytesRead.addingReportingOverflow(byteCount)
                guard !overflow else { throw ProbeError.overflow }
                s.bytesRead = total
                s.successfulReads += 1
                if s.firstSuccessfulReadAtMilliseconds == nil { s.firstSuccessfulReadAtMilliseconds = at }
            }
        case .readFailed(let sessionID):
            try requireOpenInput(s, sessionID)
            s.failedReads += 1
        case .writeAttempted(let sessionID):
            // Recorded as blocked; nothing is transmitted.
            try requireSession(s, sessionID)
            s.blockedWriteAttempts += 1
            s.policyFlags.insert(.writeAttemptBlocked)
        case .syntheticReadiness(let fact, let value):
            guard s.origin == .mock else { throw ProbeError.syntheticObservationNotAllowed }
            switch fact {
            case .aircraftReady: s.aircraftReady = .syntheticallyReported(value)
            case .initializationComplete: s.initializationComplete = .syntheticallyReported(value)
            case .telemetryValid: s.telemetryValid = .syntheticallyReported(value)
            }
        case .sessionClosed(let sessionID):
            try requireSession(s, sessionID)
            end(&s, .sessionClosed, at)
        case .accessoryDetached(let accessoryID):
            try requireAccessory(s, accessoryID)
            end(&s, .accessoryDetached, at)
        case .operatorStopped:
            end(&s, .operatorStopped, at)
        }
        s.lastAcceptedAtMilliseconds = at
    }

    // Ending keeps the last independent observations; nothing is rewritten.
    private static func end(_ s: inout ProbeRunState, _ reason: ProbeEndReason, _ at: UInt64) {
        s.endReason = reason
        s.endedAtMilliseconds = at
    }

    private static func streamState(_ s: ProbeRunState, _ stream: ProbeStream) -> ProbeStreamState {
        stream == .input ? s.inputStream : s.outputStream
    }

    private static func setStream(_ s: inout ProbeRunState, _ stream: ProbeStream, _ value: ProbeStreamState) {
        switch stream {
        case .input:
            s.inputStream = value
        case .output:
            s.outputStream = value
            s.policyFlags.insert(.outputStreamActivity)
        }
    }

    private static func requireAccessory(_ s: ProbeRunState, _ accessoryID: UInt64) throws {
        guard let current = s.accessoryID else { throw ProbeError.accessoryNotVisible }
        guard current == accessoryID else { throw ProbeError.differentAccessory }
    }

    private static func requireAdvertised(_ s: ProbeRunState, _ protocolName: String) throws {
        guard let names = s.advertisedProtocols else { throw ProbeError.protocolsNotObserved }
        guard names.contains(protocolName) else { throw ProbeError.protocolNotAdvertised }
    }

    private static func requireSession(_ s: ProbeRunState, _ sessionID: String) throws {
        guard let current = s.sessionID else { throw ProbeError.noSession }
        guard current == sessionID else { throw ProbeError.wrongSession }
    }

    private static func requireOpenInput(_ s: ProbeRunState, _ sessionID: String) throws {
        try requireSession(s, sessionID)
        guard s.inputStream == .open else { throw ProbeError.inputNotOpen }
    }

    static func isValidIdentifier(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && value.utf8.count <= maximumIdentifierBytes
    }

    static func isValidProtocolList(_ names: [String]) -> Bool {
        let excluded = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
        return names.count <= maximumProtocols && Set(names).count == names.count && names.allSatisfy {
            (1...maximumIdentifierBytes).contains($0.utf8.count)
                && !$0.unicodeScalars.contains { excluded.contains($0) }
        }
    }
}

public struct ProbeRejectionRecord: Equatable, Sendable {
    public let index: Int
    public let error: ProbeError
}

public struct ProbeReplayReport: Equatable, Sendable {
    public let state: ProbeRunState
    public let rejections: [ProbeRejectionRecord]
}

/// Original synthetic probe fixture: MOCK origin only, replayed with REPLAY
/// delivery under the same byte and event bounds as `SyntheticReplay`.
public struct SyntheticProbeFixture: Codable, Sendable {
    public static let maximumBytes = SyntheticReplay.maximumBytes
    public static let maximumEvents = SyntheticReplay.maximumEvents
    public let schemaVersion: Int
    public let synthetic: Bool
    public let source: Provenance
    public let runID: String
    public let cohort: ProbeCohort
    public let startedAtMilliseconds: UInt64
    public let windowMilliseconds: UInt64
    public let events: [ProbeObservation]

    public static func decode(_ data: Data) throws -> SyntheticProbeFixture {
        guard data.count <= maximumBytes else { throw ProbeError.tooLarge }
        let fixture = try JSONDecoder().decode(Self.self, from: data)
        try fixture.checkEnvelope()
        return fixture
    }

    private func checkEnvelope() throws {
        guard schemaVersion == 1 else { throw ProbeError.unsupportedSchema }
        guard synthetic else { throw ProbeError.notSynthetic }
        guard source == .mock else { throw ProbeError.sourceMismatch }
        guard events.count <= Self.maximumEvents else { throw ProbeError.tooManyEvents }
    }

    /// Applies every observation in order, reports each rejection by index and
    /// expires the window if no terminal observation ended the run.
    public func replay() throws -> ProbeReplayReport {
        try checkEnvelope()
        var run = try ProbeRun(runID: runID, cohort: cohort, origin: source, delivery: .replay,
                               startedAtMilliseconds: startedAtMilliseconds,
                               windowMilliseconds: windowMilliseconds)
        var rejections: [ProbeRejectionRecord] = []
        for (index, observation) in events.enumerated() {
            do {
                try run.apply(observation)
            } catch let error as ProbeError {
                rejections.append(ProbeRejectionRecord(index: index, error: error))
            }
        }
        run.expireWindow()
        return ProbeReplayReport(state: run.state, rejections: rejections)
    }
}
