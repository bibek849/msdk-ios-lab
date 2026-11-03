import Foundation
import XCTest
import MSDKIOSCore
import MSDKIOSProbeSupport
@testable import MSDKIOSAppleTransport

// Portable checks for the M5 activation gate, budgets and stop policy (#6).
// The External Accessory binding itself is Apple-only and NOT RUN here.
final class ProbeRunControllerTests: XCTestCase {
    private let alpha = "org.example.synthetic.alpha"
    private let sha = String(repeating: "a", count: 40)
    private let session = "live-1-session"

    private func controller(
        _ activation: ProbeActivation = .sessionObservation(protocolName: "org.example.synthetic.alpha")
    ) throws -> ProbeRunController {
        try ProbeRunController(runID: "live-1", cohort: .cold, activation: activation,
                               startedAtMilliseconds: 10_000)
    }

    /// Accessory visible, `alpha` advertised, the session created and input open at 10_003.
    private func openInput(_ run: inout ProbeRunController) {
        run.record(.accessoryVisible(accessoryID: 1), at: 10_000)
        run.record(.protocolsAdvertised(accessoryID: 1, names: [alpha]), at: 10_001)
        XCTAssertTrue(run.mayCreateSession(protocolName: alpha))
        run.record(.sessionCreated(sessionID: session, protocolName: alpha), at: 10_002)
        run.record(.streamOpened(sessionID: session, stream: .input), at: 10_003)
    }

    private func profile(mode: String?, protocolName: String? = nil, basis: String? = nil,
                         source: String? = nil, declared: [String] = []) -> ProbeRunProfile {
        var info: [String: Any] = [ProbeRunProfile.declaredProtocolsKey: declared]
        info[ProbeRunProfile.modeKey] = mode
        info[ProbeRunProfile.protocolKey] = protocolName
        info[ProbeRunProfile.permissionBasisKey] = basis
        info[ProbeRunProfile.sourceKey] = source
        return ProbeRunProfile(infoDictionary: info)
    }

    func testProfileDefaultsToBlockedAndIgnoresUnsetBuildValues() {
        XCTAssertEqual(ProbeRunProfile(infoDictionary: [:]).activation, .blocked(.profileBlocked))
        let committed = profile(mode: "BLOCKED", protocolName: "", basis: "", source: "", declared: [""])
        XCTAssertEqual(committed.activation, .blocked(.profileBlocked))
        XCTAssertEqual(committed.declaredProtocols, [])
        XCTAssertEqual(profile(mode: "$(PROBE_RUN_MODE)").activation, .blocked(.profileBlocked))
        XCTAssertEqual(profile(mode: "LIVE").activation, .blocked(.unknownMode))
    }

    func testActivationRequiresSourcePermissionAndADeclaredProtocolInOrder() {
        let mode = "SESSION_OBSERVATION"
        XCTAssertEqual(profile(mode: mode).activation, .blocked(.missingSourceIdentity))
        for invalid in [String(repeating: "a", count: 39), String(repeating: "A", count: 40), "$(PROBE_SOURCE_SHA)"] {
            XCTAssertEqual(profile(mode: mode, source: invalid).activation, .blocked(.missingSourceIdentity))
        }
        XCTAssertEqual(profile(mode: mode, source: sha).activation, .blocked(.missingPermissionBasis))
        XCTAssertEqual(profile(mode: mode, basis: "owner decision", source: sha).activation,
                       .blocked(.missingProtocol))
        XCTAssertEqual(profile(mode: mode, protocolName: alpha, basis: "owner decision", source: sha).activation,
                       .blocked(.protocolNotDeclared))
        let ready = profile(mode: mode, protocolName: alpha, basis: "owner decision", source: sha, declared: [alpha])
        XCTAssertEqual(ready.activation, .sessionObservation(protocolName: alpha))
        XCTAssertFalse(ready.activation.label.contains(alpha))
        XCTAssertEqual(profile(mode: "ENUMERATION_ONLY", basis: "owner decision", source: sha).activation,
                       .enumerationOnly)
    }

    func testBlockedActivationCannotStartARun() {
        XCTAssertThrowsError(try controller(.blocked(.profileBlocked))) { error in
            XCTAssertEqual(error as? ProbeControllerError, .blocked)
        }
    }

    func testLiveRunHasLiveProvenanceAndASixtySecondWindow() throws {
        let run = try controller()
        XCTAssertEqual(run.state.origin, .live)
        XCTAssertEqual(run.state.delivery, .live)
        XCTAssertEqual(run.state.windowEndMilliseconds, 70_000)
        XCTAssertFalse(run.isEnded)
    }

    func testSessionGateAllowsOnlyTheSelectedAdvertisedProtocolOnce() throws {
        var run = try controller()
        XCTAssertFalse(run.mayCreateSession(protocolName: alpha))
        run.record(.accessoryVisible(accessoryID: 1), at: 10_000)
        run.record(.protocolsAdvertised(accessoryID: 1, names: ["org.example.synthetic.beta"]), at: 10_001)
        XCTAssertFalse(run.mayCreateSession(protocolName: alpha))
        run.record(.protocolsAdvertised(accessoryID: 1, names: [alpha, "org.example.synthetic.beta"]), at: 10_002)
        XCTAssertTrue(run.mayCreateSession(protocolName: alpha))
        XCTAssertFalse(run.mayCreateSession(protocolName: "org.example.synthetic.beta"))
        run.record(.sessionCreated(sessionID: session, protocolName: alpha), at: 10_003)
        XCTAssertFalse(run.mayCreateSession(protocolName: alpha))
    }

    func testEnumerationOnlyNeverAppliesSessionOrStreamEvents() throws {
        var run = try controller(.enumerationOnly)
        run.record(.accessoryVisible(accessoryID: 1), at: 10_000)
        run.record(.protocolsAdvertised(accessoryID: 1, names: [alpha]), at: 10_001)
        XCTAssertFalse(run.mayCreateSession(protocolName: alpha))
        run.record(.sessionCreated(sessionID: session, protocolName: alpha), at: 10_002)
        XCTAssertEqual(run.log.last?.outcome, .notPermitted)
        XCTAssertNil(run.state.sessionID)
        XCTAssertEqual(run.state.advertisedProtocols, [alpha])
    }

    func testReadLengthIsBoundedByTheChunkAndTheTotalBudget() throws {
        var run = try controller()
        XCTAssertEqual(run.nextReadLength, 0)
        openInput(&run)
        XCTAssertEqual(run.nextReadLength, ProbeBudget.readChunkBytes)
        run.record(.readCompleted(sessionID: session, byteCount: ProbeBudget.maximumTotalReadBytes - 576), at: 10_004)
        XCTAssertEqual(run.nextReadLength, 576)
    }

    func testReadBudgetStopsAtExactlyOneMebibyteWithinTheEventBudget() throws {
        var run = try controller()
        openInput(&run)
        var time: UInt64 = 10_004
        var reads = 0
        while !run.isEnded {
            let length = run.nextReadLength
            XCTAssertGreaterThan(length, 0)
            run.record(.bytesAvailable(sessionID: session), at: time)
            run.record(.readCompleted(sessionID: session, byteCount: UInt64(length)), at: time)
            time += 1
            reads += 1
        }
        XCTAssertEqual(reads, 256)
        XCTAssertEqual(run.state.bytesRead, ProbeBudget.maximumTotalReadBytes)
        XCTAssertEqual(run.state.endReason, .stopped(.readBudget))
        XCTAssertEqual(run.nextReadLength, 0)
        XCTAssertLessThan(run.log.count, 10)
        XCTAssertEqual(run.state.firstSuccessfulReadAtMilliseconds, 10_004)
    }

    func testEventBudgetStopsWithTheLastRetainedEntry() throws {
        var run = try controller()
        openInput(&run)
        var time: UInt64 = 10_004
        while !run.isEnded {
            run.record(.streamOpened(sessionID: "other-session", stream: .input), at: time)
            time += 1
        }
        XCTAssertEqual(run.log.count, ProbeBudget.maximumRetainedEvents)
        XCTAssertEqual(run.log.last?.event, .runStopped(reason: .eventBudget))
        XCTAssertEqual(run.log.last?.outcome, .accepted)
        XCTAssertEqual(run.state.endReason, .stopped(.eventBudget))
        run.record(.bytesAvailable(sessionID: session), at: time)
        XCTAssertEqual(run.log.count, ProbeBudget.maximumRetainedEvents)
        XCTAssertEqual(run.lateCallbacksIgnored, 1)
    }

    func testInputStreamErrorOrEndStopsTheRunAndRequiresCleanup() throws {
        var failed = try controller()
        openInput(&failed)
        failed.record(.streamError(sessionID: session, stream: .input), at: 10_010)
        XCTAssertEqual(failed.state.endReason, .stopped(.streamError))
        XCTAssertEqual(failed.state.inputStream, .error)
        XCTAssertTrue(failed.needsCleanup)
        failed.markCleanupCompleted(at: 10_011)
        XCTAssertFalse(failed.needsCleanup)
        XCTAssertEqual(failed.cleanupCompletedAtMilliseconds, 10_011)

        var ended = try controller()
        openInput(&ended)
        ended.record(.streamEnd(sessionID: session, stream: .input), at: 10_010)
        XCTAssertEqual(ended.state.endReason, .stopped(.streamEnd))
    }

    func testWriteAttemptIsBlockedAndDoesNotStopTheRun() throws {
        var run = try controller()
        openInput(&run)
        run.record(.writeAttempted(sessionID: session), at: 10_010)
        XCTAssertEqual(run.state.blockedWriteAttempts, 1)
        XCTAssertEqual(run.state.policyFlags, [.writeAttemptBlocked])
        XCTAssertEqual(run.state.outputStream, .notRequested)
        XCTAssertFalse(run.isEnded)
    }

    func testLateCallbacksAfterTheEndAreCountedButNotApplied() throws {
        var run = try controller()
        openInput(&run)
        run.stop(.operator, at: 10_020)
        let ended = run.state
        let entries = run.log.count
        run.record(.bytesAvailable(sessionID: session), at: 10_030)
        run.record(.accessoryDetached(accessoryID: 1), at: 10_031)
        run.stop(.appBackground, at: 10_032)
        XCTAssertEqual(run.state, ended)
        XCTAssertEqual(run.log.count, entries)
        XCTAssertEqual(run.lateCallbacksIgnored, 2)
        XCTAssertEqual(run.state.endReason, .stopped(.operator))
    }

    func testStopAfterTheWindowEndsAtExactlyTheWindowEnd() throws {
        var run = try controller()
        run.stop(.operator, at: 70_001)
        XCTAssertEqual(run.state.endReason, .windowElapsed)
        XCTAssertEqual(run.state.endedAtMilliseconds, 70_000)
    }

    func testStopIsNeverOrderedBeforeAnAcceptedObservation() throws {
        var run = try controller()
        run.record(.accessoryVisible(accessoryID: 1), at: 10_500)
        run.stop(.operator, at: 10_400)
        XCTAssertEqual(run.state.endedAtMilliseconds, 10_500)
        XCTAssertEqual(run.state.endReason, .stopped(.operator))
    }

    func testBytesNeverSetReadinessAndSyntheticReadinessIsRejectedLive() throws {
        var run = try controller()
        openInput(&run)
        run.record(.readCompleted(sessionID: session, byteCount: 4_096), at: 10_010)
        run.record(.syntheticReadiness(fact: .aircraftReady, value: true), at: 10_011)
        XCTAssertEqual(run.log.last?.outcome, .rejected(.syntheticObservationNotAllowed))
        XCTAssertEqual(run.state.aircraftReady, .unknown)
        XCTAssertEqual(run.state.initializationComplete, .unknown)
        XCTAssertEqual(run.state.telemetryValid, .unknown)
        XCTAssertFalse(ResearchCapabilities.nativeIOSTransportAvailable)
        XCTAssertFalse(ResearchCapabilities.aircraftCommandsAvailable)
        XCTAssertFalse(ResearchCapabilities.hardwareValidated)
    }

    func testSummaryNamesTheEndWithoutProtocolNamesOrPayload() throws {
        var run = try controller()
        openInput(&run)
        run.record(.readCompleted(sessionID: session, byteCount: 12), at: 10_100)
        run.stop(.operator, at: 10_200)
        run.markCleanupCompleted(at: 10_201)
        let ready = profile(mode: "SESSION_OBSERVATION", protocolName: alpha, basis: "owner decision",
                            source: sha, declared: [alpha])
        let summary = run.summary(profile: ready)
        for expected in ["source: \(sha)", "activation: SESSION_OBSERVATION", "cohort: COLD", "origin: LIVE",
                         "L5 first successful read: +100 ms", "bytes 12", "end: STOPPED_OPERATOR at +200 ms",
                         "cleanup +201 ms", "selected protocol advertised: yes", "readiness: aircraft UNKNOWN"] {
            XCTAssertTrue(summary.contains(expected), "missing \(expected) in:\n\(summary)")
        }
        XCTAssertFalse(summary.contains(alpha))
    }

    func testProbeClockIsMonotonic() {
        let first = ProbeClock.nowMilliseconds()
        XCTAssertGreaterThanOrEqual(ProbeClock.nowMilliseconds(), first)
    }
}
