import Foundation
import XCTest
import MSDKIOSCore
@testable import MSDKIOSProbeSupport

// Expected outcomes come from docs/PROBE_OBSERVATION_CONTRACT.md, not from the reducer.
final class ProbeRunTests: XCTestCase {
    private let alpha = "org.example.synthetic.alpha"

    private func at(_ time: UInt64, _ event: ProbeEvent, run: String = "run-a") -> ProbeObservation {
        ProbeObservation(runID: run, atMilliseconds: time, event: event)
    }

    /// Run `run-a`: COLD cohort, window [1_000, 61_000].
    private func newRun(origin: Provenance = .mock) throws -> ProbeRun {
        try ProbeRun(runID: "run-a", cohort: .cold, origin: origin, delivery: .replay,
                     startedAtMilliseconds: 1_000, windowMilliseconds: 60_000)
    }

    /// Accessory 1 visible and advertising `alpha`; session `s1` created at 1_020.
    private func sessionRun(origin: Provenance = .mock) throws -> ProbeRun {
        var run = try newRun(origin: origin)
        try run.apply(at(1_000, .accessoryVisible(accessoryID: 1)))
        try run.apply(at(1_010, .protocolsAdvertised(accessoryID: 1, names: [alpha])))
        try run.apply(at(1_020, .sessionCreated(sessionID: "s1", protocolName: alpha)))
        return run
    }

    private func assertRejected(
        _ expected: ProbeError, _ run: inout ProbeRun, _ observation: ProbeObservation,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let before = run.state
        XCTAssertThrowsError(try run.apply(observation), file: file, line: line) { error in
            XCTAssertEqual(error as? ProbeError, expected, file: file, line: line)
        }
        XCTAssertEqual(run.state, before, "a rejected observation changed state", file: file, line: line)
    }

    private func assertReadinessUnknown(_ state: ProbeRunState, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(state.aircraftReady, .unknown, file: file, line: line)
        XCTAssertEqual(state.initializationComplete, .unknown, file: file, line: line)
        XCTAssertEqual(state.telemetryValid, .unknown, file: file, line: line)
    }

    private func replayFixture(_ name: String) throws -> ProbeReplayReport {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("fixtures/synthetic-probe/\(name)"))
        return try SyntheticProbeFixture.decode(data).replay()
    }

    private func envelope(
        version: Int = 1, synthetic: Bool = true, source: String = "MOCK", runID: String = "run-a",
        cohort: String = "COLD", window: UInt64 = 60_000, events: [String] = []
    ) -> Data {
        Data("""
        {"schemaVersion": \(version), "synthetic": \(synthetic), "source": "\(source)", "runID": "\(runID)",
         "cohort": "\(cohort)", "startedAtMilliseconds": 0, "windowMilliseconds": \(window),
         "events": [\(events.joined(separator: ","))]}
        """.utf8)
    }

    func testValidLifecycleFixtureKeepsLayersIndependent() throws {
        let report = try replayFixture("valid-lifecycle-v1.json")
        let state = report.state
        XCTAssertEqual(report.rejections, [])
        XCTAssertEqual(state.origin, .mock)
        XCTAssertEqual(state.delivery, .replay)
        XCTAssertEqual(state.cohort, .unspecified)
        XCTAssertEqual(state.accessoryVisibleAtMilliseconds, 1_000)
        XCTAssertEqual(state.advertisedProtocols, [alpha, "org.example.synthetic.beta"])
        XCTAssertEqual(state.sessionProtocol, alpha)
        XCTAssertEqual(state.sessionCreatedAtMilliseconds, 1_300)
        XCTAssertEqual(state.inputStream, .open)
        XCTAssertEqual(state.outputStream, .notRequested)
        XCTAssertEqual(state.bytesAvailableEvents, 2)
        XCTAssertEqual(state.successfulReads, 2)
        XCTAssertEqual(state.bytesRead, 96)
        XCTAssertEqual(state.firstSuccessfulReadAtMilliseconds, 1_500)
        XCTAssertEqual(state.policyFlags, [])
        assertReadinessUnknown(state)
        // The close at exactly the window end is accepted.
        XCTAssertEqual(state.endReason, .sessionClosed)
        XCTAssertEqual(state.endedAtMilliseconds, 61_000)
        XCTAssertFalse(ResearchCapabilities.nativeIOSTransportAvailable)
        XCTAssertFalse(ResearchCapabilities.aircraftCommandsAvailable)
        XCTAssertFalse(ResearchCapabilities.hardwareValidated)
    }

    func testInputOpensWhileOutputIsNotRequestedThenOutputOpenFails() throws {
        var run = try sessionRun()
        try run.apply(at(1_030, .streamOpened(sessionID: "s1", stream: .input)))
        XCTAssertEqual(run.state.inputStream, .open)
        XCTAssertEqual(run.state.outputStream, .notRequested)
        XCTAssertEqual(run.state.policyFlags, [])
        try run.apply(at(1_040, .streamError(sessionID: "s1", stream: .output)))
        XCTAssertEqual(run.state.inputStream, .open)
        XCTAssertEqual(run.state.outputStream, .error)
        XCTAssertEqual(run.state.policyFlags, [.outputStreamActivity])
        assertRejected(.streamFinished, &run, at(1_050, .streamOpened(sessionID: "s1", stream: .output)))
        assertRejected(.streamNotOpenable, &run, at(1_050, .streamOpened(sessionID: "s1", stream: .input)))
    }

    func testOutputOpensWithoutInputSetsOnlyOutputFacts() throws {
        var run = try sessionRun()
        try run.apply(at(1_030, .streamOpened(sessionID: "s1", stream: .output)))
        XCTAssertEqual(run.state.outputStream, .open)
        XCTAssertEqual(run.state.inputStream, .notRequested)
        XCTAssertEqual(run.state.policyFlags, [.outputStreamActivity])
        assertRejected(.inputNotOpen, &run, at(1_040, .bytesAvailable(sessionID: "s1")))
        assertRejected(.inputNotOpen, &run, at(1_040, .readCompleted(sessionID: "s1", byteCount: 4)))
        assertRejected(.streamNotOpen, &run, at(1_050, .streamEnd(sessionID: "s1", stream: .input)))
        XCTAssertNil(run.state.firstSuccessfulReadAtMilliseconds)
        XCTAssertEqual(run.state.bytesRead, 0)
    }

    func testOpenStreamWithoutBytesExpiresAtExactWindowEnd() throws {
        let report = try replayFixture("open-without-bytes-v1.json")
        XCTAssertEqual(report.rejections, [])
        XCTAssertEqual(report.state.cohort, .cold)
        XCTAssertEqual(report.state.inputStream, .open)
        XCTAssertNil(report.state.firstSuccessfulReadAtMilliseconds)
        XCTAssertEqual(report.state.bytesRead, 0)
        XCTAssertEqual(report.state.endReason, .windowElapsed)
        XCTAssertEqual(report.state.endedAtMilliseconds, 5_000)
        assertReadinessUnknown(report.state)
    }

    func testBytesLeaveReadinessUnknownEvenWithBothStreamsOpen() throws {
        var run = try sessionRun()
        try run.apply(at(1_030, .streamOpened(sessionID: "s1", stream: .input)))
        try run.apply(at(1_031, .streamOpened(sessionID: "s1", stream: .output)))
        for offset in 0..<UInt64(5) {
            try run.apply(at(1_040 + offset, .readCompleted(sessionID: "s1", byteCount: 1_024)))
        }
        XCTAssertEqual(run.state.successfulReads, 5)
        XCTAssertEqual(run.state.bytesRead, 5_120)
        assertReadinessUnknown(run.state)
    }

    func testBytesAvailableThenZeroByteAndFailedReadsSetNoFirstInput() throws {
        var run = try sessionRun()
        try run.apply(at(1_030, .streamOpened(sessionID: "s1", stream: .input)))
        try run.apply(at(1_040, .bytesAvailable(sessionID: "s1")))
        try run.apply(at(1_040, .readCompleted(sessionID: "s1", byteCount: 0)))
        try run.apply(at(1_041, .readFailed(sessionID: "s1")))
        XCTAssertNil(run.state.firstSuccessfulReadAtMilliseconds)
        XCTAssertEqual(run.state.bytesAvailableEvents, 1)
        XCTAssertEqual(run.state.zeroByteReads, 1)
        XCTAssertEqual(run.state.failedReads, 1)
        XCTAssertEqual(run.state.successfulReads, 0)
        XCTAssertEqual(run.state.bytesRead, 0)
        assertReadinessUnknown(run.state)
        try run.apply(at(1_050, .readCompleted(sessionID: "s1", byteCount: 2)))
        XCTAssertEqual(run.state.firstSuccessfulReadAtMilliseconds, 1_050)
    }

    func testCloseIsTerminalAndLateCallbacksAreRejected() throws {
        let report = try replayFixture("late-callbacks-v1.json")
        XCTAssertEqual(report.rejections, [
            ProbeRejectionRecord(index: 6, error: .runEnded),
            ProbeRejectionRecord(index: 7, error: .runEnded),
            ProbeRejectionRecord(index: 8, error: .runEnded),
            ProbeRejectionRecord(index: 9, error: .wrongRun)
        ])
        XCTAssertEqual(report.state.endReason, .sessionClosed)
        XCTAssertEqual(report.state.endedAtMilliseconds, 3_000)
        XCTAssertEqual(report.state.cohort, .primed)
        XCTAssertEqual(report.state.bytesRead, 16)
        XCTAssertEqual(report.state.outputStream, .notRequested)
        XCTAssertEqual(report.state.policyFlags, [])
        assertReadinessUnknown(report.state)
    }

    func testDuplicateCloseIsRejectedAndEndIsUnchanged() throws {
        var run = try sessionRun()
        try run.apply(at(1_100, .sessionClosed(sessionID: "s1")))
        assertRejected(.runEnded, &run, at(1_200, .sessionClosed(sessionID: "s1")))
        run.expireWindow()
        XCTAssertEqual(run.state.endReason, .sessionClosed)
        XCTAssertEqual(run.state.endedAtMilliseconds, 1_100)
    }

    func testDetachIsTerminalAndKeepsLastStreamStates() throws {
        var run = try sessionRun()
        try run.apply(at(1_030, .streamOpened(sessionID: "s1", stream: .input)))
        try run.apply(at(1_040, .accessoryDetached(accessoryID: 1)))
        XCTAssertEqual(run.state.endReason, .accessoryDetached)
        XCTAssertEqual(run.state.endedAtMilliseconds, 1_040)
        XCTAssertEqual(run.state.inputStream, .open)
        assertRejected(.runEnded, &run, at(1_050, .readCompleted(sessionID: "s1", byteCount: 1)))
        assertRejected(.runEnded, &run, at(1_060, .accessoryVisible(accessoryID: 1)))
        assertRejected(.runEnded, &run, at(1_070, .streamEnd(sessionID: "s1", stream: .input)))
    }

    func testObservationFromAnotherRunCannotMutateTheCurrentRun() throws {
        var run = try sessionRun()
        let lateEvents: [ProbeEvent] = [
            .sessionClosed(sessionID: "s1"), .streamOpened(sessionID: "s1", stream: .input),
            .syntheticReadiness(fact: .aircraftReady, value: true), .runStopped(reason: .operator)
        ]
        for event in lateEvents {
            assertRejected(.wrongRun, &run, at(1_030, event, run: "run-old"))
        }
        XCTAssertEqual(run.state.cohort, .cold)
        XCTAssertNil(run.state.endReason)
    }

    func testExactWindowBoundary() throws {
        var run = try sessionRun()
        try run.apply(at(61_000, .streamOpened(sessionID: "s1", stream: .input)))
        assertRejected(.afterWindow, &run, at(61_001, .bytesAvailable(sessionID: "s1")))
        XCTAssertNil(run.state.endReason)
        run.expireWindow()
        XCTAssertEqual(run.state.endReason, .windowElapsed)
        XCTAssertEqual(run.state.endedAtMilliseconds, 61_000)
        XCTAssertEqual(run.state.inputStream, .open)
    }

    func testClockOrderingAndWindowCreation() throws {
        var run = try sessionRun()
        assertRejected(.outOfOrder, &run, at(1_019, .streamOpened(sessionID: "s1", stream: .input)))
        try run.apply(at(1_020, .streamOpened(sessionID: "s1", stream: .input)))
        var fresh = try newRun()
        assertRejected(.beforeStart, &fresh, at(999, .accessoryVisible(accessoryID: 1)))
        let invalidWindows: [(start: UInt64, window: UInt64)] = [(0, 0), (0, 60_001), (UInt64.max - 59_999, 60_000)]
        for (start, window) in invalidWindows {
            XCTAssertThrowsError(try ProbeRun(runID: "run-a", cohort: .cold, origin: .mock, delivery: .replay,
                                              startedAtMilliseconds: start, windowMilliseconds: window)) { error in
                XCTAssertEqual(error as? ProbeError, .invalidWindow)
            }
        }
        let edge = try ProbeRun(runID: "run-a", cohort: .cold, origin: .mock, delivery: .replay,
                                startedAtMilliseconds: UInt64.max - 60_000, windowMilliseconds: 60_000)
        XCTAssertEqual(edge.state.windowEndMilliseconds, UInt64.max)
    }

    func testWrongSessionAndLayerOrderingRejected() throws {
        var run = try newRun()
        assertRejected(.accessoryNotVisible, &run, at(1_000, .protocolsAdvertised(accessoryID: 1, names: [alpha])))
        try run.apply(at(1_000, .accessoryVisible(accessoryID: 1)))
        assertRejected(.accessoryAlreadyVisible, &run, at(1_001, .accessoryVisible(accessoryID: 1)))
        assertRejected(.differentAccessory, &run, at(1_001, .accessoryVisible(accessoryID: 2)))
        assertRejected(.protocolsNotObserved, &run, at(1_002, .sessionCreated(sessionID: "s1", protocolName: alpha)))
        assertRejected(.noSession, &run, at(1_002, .streamOpened(sessionID: "s1", stream: .input)))
        try run.apply(at(1_003, .protocolsAdvertised(accessoryID: 1, names: [alpha])))
        assertRejected(.protocolNotAdvertised, &run,
                       at(1_004, .sessionCreated(sessionID: "s1", protocolName: "org.example.synthetic.beta")))
        try run.apply(at(1_005, .sessionCreated(sessionID: "s1", protocolName: alpha)))
        assertRejected(.sessionAlreadyCreated, &run, at(1_006, .sessionCreated(sessionID: "s2", protocolName: alpha)))
        assertRejected(.sessionAlreadyCreated, &run, at(1_006, .sessionCreationFailed(protocolName: alpha)))
        assertRejected(.wrongSession, &run, at(1_007, .streamOpened(sessionID: "s2", stream: .input)))
        assertRejected(.wrongSession, &run, at(1_007, .sessionClosed(sessionID: "s2")))
        assertRejected(.inputNotOpen, &run, at(1_008, .readFailed(sessionID: "s1")))
        assertRejected(.differentAccessory, &run, at(1_008, .accessoryDetached(accessoryID: 2)))
    }

    func testSessionCreationFailureIsSeparateFromASession() throws {
        var run = try newRun()
        try run.apply(at(1_000, .accessoryVisible(accessoryID: 1)))
        try run.apply(at(1_001, .protocolsAdvertised(accessoryID: 1, names: [alpha])))
        try run.apply(at(1_002, .sessionCreationFailed(protocolName: alpha)))
        XCTAssertEqual(run.state.sessionCreationFailures, 1)
        XCTAssertNil(run.state.sessionID)
        assertRejected(.noSession, &run, at(1_003, .writeAttempted(sessionID: "s1")))
    }

    func testWriteAttemptIsBlockedAndChangesNothingElse() throws {
        var run = try sessionRun()
        try run.apply(at(1_030, .streamOpened(sessionID: "s1", stream: .input)))
        let before = run.state
        try run.apply(at(1_040, .writeAttempted(sessionID: "s1")))
        XCTAssertEqual(run.state.blockedWriteAttempts, 1)
        XCTAssertEqual(run.state.policyFlags, [.writeAttemptBlocked])
        XCTAssertEqual(run.state.outputStream, .notRequested)
        XCTAssertEqual(run.state.inputStream, before.inputStream)
        XCTAssertEqual(run.state.bytesRead, before.bytesRead)
        XCTAssertNil(run.state.endReason)
        assertReadinessUnknown(run.state)
        XCTAssertFalse(ResearchCapabilities.aircraftCommandsAvailable)
    }

    func testSyntheticReadinessOnlyFromAnExplicitMockObservation() throws {
        var run = try sessionRun()
        try run.apply(at(1_030, .syntheticReadiness(fact: .telemetryValid, value: false)))
        XCTAssertEqual(run.state.telemetryValid, .syntheticallyReported(false))
        XCTAssertEqual(run.state.aircraftReady, .unknown)
        XCTAssertEqual(run.state.initializationComplete, .unknown)
        var live = try sessionRun(origin: .live)
        assertRejected(.syntheticObservationNotAllowed, &live,
                       at(1_030, .syntheticReadiness(fact: .aircraftReady, value: true)))
    }

    func testEmptyThenPopulatedProtocolList() throws {
        var run = try newRun()
        try run.apply(at(1_000, .accessoryVisible(accessoryID: 1)))
        try run.apply(at(1_001, .protocolsAdvertised(accessoryID: 1, names: [])))
        XCTAssertEqual(run.state.advertisedProtocols, [])
        assertRejected(.protocolNotAdvertised, &run, at(1_002, .sessionCreated(sessionID: "s1", protocolName: alpha)))
        try run.apply(at(1_003, .protocolsAdvertised(accessoryID: 1, names: [alpha])))
        try run.apply(at(1_004, .sessionCreated(sessionID: "s1", protocolName: alpha)))
        XCTAssertEqual(run.state.sessionCreatedAtMilliseconds, 1_004)
    }

    func testByteTotalOverflowRejected() throws {
        var run = try sessionRun()
        try run.apply(at(1_030, .streamOpened(sessionID: "s1", stream: .input)))
        try run.apply(at(1_040, .readCompleted(sessionID: "s1", byteCount: UInt64.max)))
        assertRejected(.overflow, &run, at(1_050, .readCompleted(sessionID: "s1", byteCount: 1)))
        XCTAssertEqual(run.state.bytesRead, UInt64.max)
    }

    func testInvalidIdentifiersAndProtocolLists() throws {
        for id in ["", " \n", String(repeating: "a", count: 129)] {
            XCTAssertThrowsError(try ProbeRun(runID: id, cohort: .cold, origin: .mock, delivery: .replay,
                                              startedAtMilliseconds: 0, windowMilliseconds: 1)) { error in
                XCTAssertEqual(error as? ProbeError, .invalidRun)
            }
        }
        var run = try newRun()
        try run.apply(at(1_000, .accessoryVisible(accessoryID: 1)))
        let tooMany = (0..<33).map { "org.example.synthetic.p\($0)" }
        let invalidLists: [[String]] = [[""], ["org.example.synthetic alpha"], ["org.example.\u{7}"],
                                        [alpha, alpha], tooMany, [String(repeating: "a", count: 129)]]
        for names in invalidLists {
            assertRejected(.invalidProtocolList, &run, at(1_001, .protocolsAdvertised(accessoryID: 1, names: names)))
        }
        try run.apply(at(1_002, .protocolsAdvertised(accessoryID: 1, names: [String(repeating: "a", count: 128)])))
        try run.apply(at(1_003, .protocolsAdvertised(accessoryID: 1, names: [alpha])))
        assertRejected(.invalidSession, &run, at(1_004, .sessionCreated(sessionID: " ", protocolName: alpha)))
    }

    func testFixtureEnvelopeAndBounds() throws {
        func assertFixture(_ expected: ProbeError, _ data: Data, line: UInt = #line) {
            XCTAssertThrowsError(try SyntheticProbeFixture.decode(data).replay(), line: line) { error in
                XCTAssertEqual(error as? ProbeError, expected, line: line)
            }
        }
        assertFixture(.tooLarge, Data(repeating: 32, count: SyntheticProbeFixture.maximumBytes + 1))
        let stop = #"{"runID": "run-a", "atMilliseconds": 0, "kind": "RUN_STOPPED", "reason": "OPERATOR"}"#
        assertFixture(.tooManyEvents, envelope(events: Array(repeating: stop, count: 257)))
        let full = try SyntheticProbeFixture.decode(envelope(events: Array(repeating: stop, count: 256))).replay()
        XCTAssertEqual(full.state.endReason, .stopped(.operator))
        XCTAssertEqual(full.rejections.count, 255)
        assertFixture(.notSynthetic, envelope(synthetic: false))
        assertFixture(.sourceMismatch, envelope(source: "LIVE"))
        assertFixture(.unsupportedSchema, envelope(version: 2))
        assertFixture(.invalidRun, envelope(runID: String(repeating: "a", count: 129)))
        assertFixture(.invalidWindow, envelope(window: 60_001))
    }

    func testMalformedValuesFailDecodingAndExtraFieldsAreIgnored() throws {
        let malformed = [
            #"{"runID": "run-a", "atMilliseconds": 0, "kind": "UNKNOWN_KIND"}"#,
            #"{"runID": "run-a", "atMilliseconds": -1, "kind": "RUN_STOPPED", "reason": "OPERATOR"}"#,
            #"{"runID": "run-a", "atMilliseconds": 18446744073709551616, "kind": "RUN_STOPPED", "reason": "OPERATOR"}"#,
            #"{"runID": "run-a", "atMilliseconds": 0, "kind": "RUN_STOPPED"}"#,
            #"{"runID": "run-a", "atMilliseconds": 0, "kind": "RUN_STOPPED", "reason": "TIRED"}"#,
            #"{"runID": "run-a", "atMilliseconds": 0, "kind": "READ_COMPLETED", "sessionID": "s1", "byteCount": -1}"#,
            #"{"runID": "run-a", "atMilliseconds": 0, "kind": "READ_COMPLETED", "sessionID": "s1"}"#,
            #"{"runID": "run-a", "atMilliseconds": 0, "kind": "STREAM_OPENED", "sessionID": "s1", "stream": "BOTH"}"#,
            #"{"runID": "run-a", "atMilliseconds": 0, "kind": "SYNTHETIC_READINESS", "fact": "AIRCRAFT_READY", "value": "yes"}"#
        ]
        for event in malformed {
            XCTAssertThrowsError(try SyntheticProbeFixture.decode(envelope(events: [event]))) { error in
                XCTAssertTrue(error is DecodingError, "\(event): \(error)")
            }
        }
        XCTAssertThrowsError(try SyntheticProbeFixture.decode(envelope(cohort: "WARM"))) { error in
            XCTAssertTrue(error is DecodingError)
        }
        XCTAssertThrowsError(try SyntheticProbeFixture.decode(Data("{".utf8)))
        let extra = #"{"runID": "run-a", "atMilliseconds": 0, "kind": "RUN_STOPPED", "reason": "READ_BUDGET", "note": "ignored"}"#
        XCTAssertEqual(try SyntheticProbeFixture.decode(envelope(events: [extra])).replay().state.endReason,
                       .stopped(.readBudget))
    }

    func testEveryObservationKindRoundTripsThroughJSON() throws {
        let events: [ProbeEvent] = [
            .accessoryVisible(accessoryID: 1), .protocolsAdvertised(accessoryID: 1, names: [alpha]),
            .sessionCreated(sessionID: "s1", protocolName: alpha), .sessionCreationFailed(protocolName: alpha),
            .streamOpened(sessionID: "s1", stream: .input), .streamError(sessionID: "s1", stream: .output),
            .streamEnd(sessionID: "s1", stream: .input), .bytesAvailable(sessionID: "s1"),
            .readCompleted(sessionID: "s1", byteCount: UInt64.max), .readFailed(sessionID: "s1"),
            .writeAttempted(sessionID: "s1"), .syntheticReadiness(fact: .initializationComplete, value: true),
            .sessionClosed(sessionID: "s1"), .accessoryDetached(accessoryID: 1)
        ] + ProbeStopReason.allCases.map { .runStopped(reason: $0) }
        for event in events {
            let observation = ProbeObservation(runID: "run-a", atMilliseconds: 5, event: event)
            let decoded = try JSONDecoder().decode(ProbeObservation.self, from: JSONEncoder().encode(observation))
            XCTAssertEqual(decoded, observation)
        }
    }
}
