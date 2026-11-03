import Foundation
import MSDKIOSCore
import MSDKIOSProbeSupport

/// Diagnostic budgets for one live run (#6). These are observation limits
/// chosen by this project, not properties of any accessory protocol.
public enum ProbeBudget {
    public static let maximumWindowMilliseconds: UInt64 = 60_000
    public static let maximumRetainedEvents = 256
    public static let readChunkBytes = 4_096
    public static let maximumTotalReadBytes: UInt64 = 1_048_576
}

public enum ProbeLogOutcome: Equatable, Sendable {
    case accepted
    case rejected(ProbeError)
    /// The run's activation does not allow this observation, so it was not applied.
    case notPermitted
}

/// One retained diagnostic entry: identifiers, counts and times only, never payload.
public struct ProbeLogEntry: Equatable, Sendable {
    public let atMilliseconds: UInt64
    public let event: ProbeEvent
    public let outcome: ProbeLogOutcome
}

public enum ProbeControllerError: String, Error, Sendable {
    case blocked
}

/// Owns one live run. It applies adapter observations to the M4 reducer,
/// enforces the budgets, and stops the run on an input-stream error or end.
/// It is platform-independent and deterministic: the Apple adapter only
/// translates callbacks and performs the single reads and the close it asks for.
/// It has no transmit path and never changes `ResearchCapabilities`.
public struct ProbeRunController: Sendable {
    public let activation: ProbeActivation
    public private(set) var run: ProbeRun
    public private(set) var log: [ProbeLogEntry] = []
    public private(set) var lateCallbacksIgnored = 0
    public private(set) var cleanupCompletedAtMilliseconds: UInt64?
    private var retainedReadPathKinds: Set<ReadPathKind> = []

    public init(runID: String, cohort: ProbeCohort, activation: ProbeActivation,
                startedAtMilliseconds: UInt64) throws {
        guard activation.permitsObservation else { throw ProbeControllerError.blocked }
        self.activation = activation
        run = try ProbeRun(runID: runID, cohort: cohort, origin: .live, delivery: .live,
                           startedAtMilliseconds: startedAtMilliseconds,
                           windowMilliseconds: ProbeBudget.maximumWindowMilliseconds)
    }

    public var state: ProbeRunState { run.state }
    public var isEnded: Bool { run.state.endReason != nil }
    public var needsCleanup: Bool { isEnded && cleanupCompletedAtMilliseconds == nil }

    /// Bytes for the adapter's next single read: at most 4 KiB and never past
    /// the 1 MiB total. Zero once the run has ended or while input is not open.
    public var nextReadLength: Int {
        guard !isEnded, state.inputStream == .open,
              state.bytesRead < ProbeBudget.maximumTotalReadBytes else { return 0 }
        let remaining = ProbeBudget.maximumTotalReadBytes - state.bytesRead
        return Int(min(UInt64(ProbeBudget.readChunkBytes), remaining))
    }

    /// Whether the adapter may create the run's one session on `protocolName` now.
    public func mayCreateSession(protocolName: String) -> Bool {
        guard case .sessionObservation(let selected) = activation, selected == protocolName,
              !isEnded, state.sessionID == nil else { return false }
        return state.advertisedProtocols?.contains(protocolName) == true
    }

    /// Records one adapter observation. Every accepted observation updates the
    /// run's counters; the log retains each distinct event, every rejection and
    /// the first of each repeated read-path event (bytes available, successful,
    /// zero-byte and failed reads), so 1 MiB of 4 KiB reads fits the 256-entry
    /// budget. Once the run has ended, callbacks are counted but not retained,
    /// so a stale callback can neither revive the run nor grow the log.
    public mutating func record(_ event: ProbeEvent, at: UInt64) {
        guard !isEnded else {
            noteLateCallback()
            return
        }
        if case .enumerationOnly = activation, Self.requiresSession(event) {
            append(at, event, .notPermitted)
        } else {
            do {
                try run.apply(ProbeObservation(runID: state.runID, atMilliseconds: at, event: event))
                if let kind = ReadPathKind(event) {
                    if retainedReadPathKinds.insert(kind).inserted { append(at, event, .accepted) }
                } else {
                    append(at, event, .accepted)
                }
            } catch {
                append(at, event, .rejected(error))
            }
        }
        applyStopPolicy(after: event, at: at)
    }

    /// Ends the run with `reason` (operator, budget, stream or backgrounding).
    /// A request after the window end ends the run as WINDOW_ELAPSED instead.
    public mutating func stop(_ reason: ProbeStopReason, at: UInt64) {
        guard !isEnded else { return }
        guard at <= state.windowEndMilliseconds else {
            expireWindow()
            return
        }
        // A stop is never ordered before an accepted observation.
        let time = max(at, state.lastAcceptedAtMilliseconds ?? state.startedAtMilliseconds)
        let event = ProbeEvent.runStopped(reason: reason)
        do {
            try run.apply(ProbeObservation(runID: state.runID, atMilliseconds: time, event: event))
            append(time, event, .accepted)
        } catch {
            append(time, event, .rejected(error))
        }
    }

    /// Ends the run at exactly the window end; does nothing once ended.
    public mutating func expireWindow() {
        run.expireWindow()
    }

    public mutating func noteLateCallback() {
        if lateCallbacksIgnored < Int.max { lateCallbacksIgnored += 1 }
    }

    /// Records that the adapter closed its stream and released its session.
    public mutating func markCleanupCompleted(at: UInt64) {
        guard isEnded, cleanupCompletedAtMilliseconds == nil else { return }
        cleanupCompletedAtMilliseconds = at
    }

    private mutating func append(_ at: UInt64, _ event: ProbeEvent, _ outcome: ProbeLogOutcome) {
        // A hard cap even if a stop were ever rejected; the stop policy normally ends the run first.
        guard log.count < ProbeBudget.maximumRetainedEvents else { return }
        log.append(ProbeLogEntry(atMilliseconds: at, event: event, outcome: outcome))
    }

    private mutating func applyStopPolicy(after event: ProbeEvent, at: UInt64) {
        guard !isEnded else { return }
        if case .streamError(_, .input) = event, state.inputStream == .error {
            stop(.streamError, at: at)
        } else if case .streamEnd(_, .input) = event, state.inputStream == .end {
            stop(.streamEnd, at: at)
        } else if state.bytesRead >= ProbeBudget.maximumTotalReadBytes {
            stop(.readBudget, at: at)
        } else if log.count >= ProbeBudget.maximumRetainedEvents - 1 {
            // The last slot holds the stop entry, so the log never exceeds the budget.
            stop(.eventBudget, at: at)
        }
    }

    private enum ReadPathKind: Hashable, Sendable {
        case bytesAvailable, successfulRead, zeroByteRead, failedRead

        init?(_ event: ProbeEvent) {
            switch event {
            case .bytesAvailable: self = .bytesAvailable
            case .readCompleted(_, let byteCount): self = byteCount == 0 ? .zeroByteRead : .successfulRead
            case .readFailed: self = .failedRead
            default: return nil
            }
        }
    }

    private static func requiresSession(_ event: ProbeEvent) -> Bool {
        switch event {
        case .sessionCreated, .sessionCreationFailed, .streamOpened, .streamError, .streamEnd,
             .bytesAvailable, .readCompleted, .readFailed, .writeAttempted, .sessionClosed:
            return true
        case .accessoryVisible, .protocolsAdvertised, .syntheticReadiness, .accessoryDetached, .runStopped:
            return false
        }
    }
}

extension ProbeRunController {
    /// A plain-text run record for the owner's notes. It contains counts, states
    /// and times relative to the run start; never payload, protocol names,
    /// accessory names or serial numbers.
    public func summary(profile: ProbeRunProfile) -> String {
        let s = state
        func relative(_ time: UInt64?) -> String {
            guard let time else { return "not observed" }
            return "+\(time >= s.startedAtMilliseconds ? time - s.startedAtMilliseconds : 0) ms"
        }
        func firstAccepted(_ matches: (ProbeEvent) -> Bool) -> UInt64? {
            log.first { $0.outcome == .accepted && matches($0.event) }?.atMilliseconds
        }
        func readiness(_ value: SyntheticReadiness) -> String {
            switch value {
            case .unknown: return "UNKNOWN"
            case .syntheticallyReported(let flag): return flag ? "SYNTHETIC_TRUE" : "SYNTHETIC_FALSE"
            }
        }
        let advertisedAt = firstAccepted { if case .protocolsAdvertised = $0 { return true } else { return false } }
        let inputOpenedAt = firstAccepted { if case .streamOpened(_, .input) = $0 { return true } else { return false } }
        let selectedAdvertised: String
        if case .sessionObservation(let name) = activation, let advertised = s.advertisedProtocols {
            selectedAdvertised = advertised.contains(name) ? "yes" : "no"
        } else {
            selectedAdvertised = "n/a"
        }
        let rejected = log.filter { if case .rejected = $0.outcome { return true } else { return false } }.count
        let notPermitted = log.filter { $0.outcome == .notPermitted }.count
        let flags = s.policyFlags.map(\.rawValue).sorted()
        return [
            "ControllerProbe run summary - diagnostic only; no application-level writes",
            "source: \(profile.sourceSHA ?? "MISSING")  activation: \(activation.label)",
            "run: \(s.runID)  cohort: \(s.cohort.rawValue)  origin: \(s.origin.rawValue)  window: \(ProbeBudget.maximumWindowMilliseconds) ms",
            "L1 accessory visible: \(relative(s.accessoryVisibleAtMilliseconds))",
            "L2 protocols advertised: \(relative(advertisedAt)); count \(s.advertisedProtocols.map { String($0.count) } ?? "-"); selected protocol advertised: \(selectedAdvertised)",
            "L3 session: \(s.sessionID == nil ? "not created" : "created \(relative(s.sessionCreatedAtMilliseconds))"); creation failures \(s.sessionCreationFailures)",
            "L4 input: \(s.inputStream.rawValue) (opened \(relative(inputOpenedAt)))  output: \(s.outputStream.rawValue)",
            "L5 first successful read: \(relative(s.firstSuccessfulReadAtMilliseconds)); reads \(s.successfulReads), bytes \(s.bytesRead), zero-byte \(s.zeroByteReads), failed \(s.failedReads), bytes-available events \(s.bytesAvailableEvents)",
            "readiness: aircraft \(readiness(s.aircraftReady)), initialization \(readiness(s.initializationComplete)), telemetry \(readiness(s.telemetryValid))",
            "end: \(s.endReason?.label ?? "RUNNING") at \(relative(s.endedAtMilliseconds)); cleanup \(relative(cleanupCompletedAtMilliseconds))",
            "flags: \(flags.isEmpty ? "none" : flags.joined(separator: ",")); blocked write attempts \(s.blockedWriteAttempts)",
            "entries: \(log.count)/\(ProbeBudget.maximumRetainedEvents) retained, \(rejected) rejected, \(notPermitted) not permitted; late callbacks ignored \(lateCallbacksIgnored)",
        ].joined(separator: "\n")
    }
}
