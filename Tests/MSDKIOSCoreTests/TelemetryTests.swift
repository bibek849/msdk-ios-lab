import Foundation
import XCTest
@testable import MSDKIOSCore

final class TelemetryTests: XCTestCase {
    private func packet(
        sequence: UInt64 = 0, schemaVersion: Int = 1, sessionID: String = "test",
        source: Provenance = .mock, timestamp: Int64? = nil,
        altitude: Double? = nil, battery: Double? = nil
    ) -> TelemetryPacket {
        TelemetryPacket(schemaVersion: schemaVersion, sessionID: sessionID,
                        sequence: sequence, source: source,
                        sourceTimestampUnixMilliseconds: timestamp,
                        altitudeRelativeMeters: altitude, batteryPercent: battery)
    }

    private func assertRejected(
        _ expected: TelemetryError, session: inout TelemetrySession,
        packet: TelemetryPacket, received: UInt64 = 0, now: UInt64 = 0,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try session.accept(packet, receivedAtMilliseconds: received, nowMilliseconds: now),
            file: file, line: line
        ) { error in
            XCTAssertEqual(error as? TelemetryError, expected, file: file, line: line)
        }
    }

    private func fixtureData(
        version: Int = 1, synthetic: Bool = true,
        source: String = "MOCK", count: Int = 1
    ) throws -> Data {
        let events: [[String: Any]] = (0..<count).map { sequence in
            ["receivedAtMilliseconds": 0, "nowMilliseconds": 10,
             "packet": ["schemaVersion": 1, "sessionID": "test", "sequence": sequence,
                        "source": source, "sourceTimestampUnixMilliseconds": NSNull(),
                        "altitudeRelativeMeters": NSNull(), "batteryPercent": NSNull()]]
        }
        return try JSONSerialization.data(withJSONObject: [
            "schemaVersion": version, "synthetic": synthetic,
            "sessionID": "test", "events": events
        ])
    }

    func testUnknownMeasurementsRoundTripAsExplicitNull() throws {
        let data = try JSONEncoder().encode(packet())
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertTrue(json["altitudeRelativeMeters"] is NSNull)
        XCTAssertTrue(json["batteryPercent"] is NSNull)
        XCTAssertTrue(json["sourceTimestampUnixMilliseconds"] is NSNull)
        XCTAssertEqual(try JSONDecoder().decode(TelemetryPacket.self, from: data), packet())
    }

    func testReplayDeliveryCannotBecomeLiveFromRecordedOrigin() throws {
        var session = try TelemetrySession(sessionID: "test", delivery: .replay)
        let sample = try session.accept(packet(source: .live), receivedAtMilliseconds: 100,
                                        nowMilliseconds: 110)
        XCTAssertEqual(sample.delivery, .replay)
        XCTAssertEqual(sample.packet.source, .live)
        XCTAssertFalse(ResearchCapabilities.nativeIOSTransportAvailable)
        XCTAssertFalse(ResearchCapabilities.aircraftCommandsAvailable)
        XCTAssertFalse(ResearchCapabilities.hardwareValidated)
    }

    func testStaleRejectedAtBoundaryWithoutConsumingSequence() throws {
        var session = try TelemetrySession(sessionID: "test", delivery: .replay)
        assertRejected(.stale, session: &session, packet: packet(), now: 1_001)
        let accepted = try session.accept(packet(), receivedAtMilliseconds: 0,
                                          nowMilliseconds: 1_000)
        XCTAssertEqual(accepted.localAgeMilliseconds, 1_000)
    }

    func testSenderTimestampDoesNotDetermineLocalAge() throws {
        var session = try TelemetrySession(sessionID: "test", delivery: .replay)
        let accepted = try session.accept(packet(timestamp: 0), receivedAtMilliseconds: 5_000,
                                          nowMilliseconds: 5_007)
        XCTAssertEqual(accepted.localAgeMilliseconds, 7)
        XCTAssertEqual(accepted.packet.sourceTimestampUnixMilliseconds, 0)
    }

    func testInvalidLocalClockRejected() throws {
        var session = try TelemetrySession(sessionID: "test", delivery: .replay)
        assertRejected(.invalidClock, session: &session, packet: packet(), received: 10, now: 9)
    }

    func testDuplicateAndOlderSequencesRejected() throws {
        var session = try TelemetrySession(sessionID: "test", delivery: .replay)
        _ = try session.accept(packet(sequence: 8), receivedAtMilliseconds: 0, nowMilliseconds: 0)
        assertRejected(.nonIncreasingSequence, session: &session, packet: packet(sequence: 8))
        assertRejected(.nonIncreasingSequence, session: &session, packet: packet(sequence: 7))
        _ = try session.accept(packet(sequence: 9), receivedAtMilliseconds: 0, nowMilliseconds: 0)
    }

    func testMaximumSequenceDoesNotWrap() throws {
        var session = try TelemetrySession(sessionID: "test", delivery: .replay)
        _ = try session.accept(packet(sequence: UInt64.max), receivedAtMilliseconds: 0,
                               nowMilliseconds: 0)
        assertRejected(.nonIncreasingSequence, session: &session, packet: packet(sequence: 0))
    }

    func testOutOfSessionRejected() throws {
        var session = try TelemetrySession(sessionID: "test", delivery: .replay)
        assertRejected(.wrongSession, session: &session, packet: packet(sessionID: "other"))
    }

    func testInvalidSessionIdentifiersRejected() {
        for id in ["", " \n", String(repeating: "a", count: 129)] {
            XCTAssertThrowsError(try TelemetrySession(sessionID: id, delivery: .mock)) { error in
                XCTAssertEqual(error as? TelemetryError, .invalidSession)
            }
        }
    }

    func testUnknownPacketAndFixtureVersionsRejected() throws {
        var session = try TelemetrySession(sessionID: "test", delivery: .replay)
        assertRejected(.unsupportedSchema, session: &session, packet: packet(schemaVersion: 2))
        XCTAssertThrowsError(try SyntheticReplay.decode(fixtureData(version: 2))) { error in
            XCTAssertEqual(error as? TelemetryError, .unsupportedSchema)
        }
    }

    func testNonFiniteAndOutOfRangeMeasurementsRejected() throws {
        var session = try TelemetrySession(sessionID: "test", delivery: .replay)
        for battery in [-0.1, 100.1, Double.nan, Double.infinity] {
            assertRejected(.invalidMeasurement, session: &session, packet: packet(battery: battery))
        }
        for altitude in [Double.nan, Double.infinity, -Double.infinity] {
            assertRejected(.invalidMeasurement, session: &session, packet: packet(altitude: altitude))
        }
        assertRejected(.invalidSourceTimestamp, session: &session, packet: packet(timestamp: -1))
    }

    func testNegativeRelativeAltitudeAndBatteryEndpointsAreValid() throws {
        var session = try TelemetrySession(sessionID: "test", delivery: .replay)
        _ = try session.accept(packet(altitude: -1.25, battery: 0), receivedAtMilliseconds: 0,
                               nowMilliseconds: 0)
        _ = try session.accept(packet(sequence: 1, battery: 100), receivedAtMilliseconds: 0,
                               nowMilliseconds: 0)
    }

    func testFixtureByteAndEventBounds() throws {
        XCTAssertThrowsError(try SyntheticReplay.decode(Data(repeating: 32, count: 262_145))) { error in
            XCTAssertEqual(error as? TelemetryError, .tooLarge)
        }
        XCTAssertThrowsError(try SyntheticReplay.decode(fixtureData(count: 257))) { error in
            XCTAssertEqual(error as? TelemetryError, .tooManyEvents)
        }
        XCTAssertEqual(try SyntheticReplay.decode(fixtureData(count: 256)).validate().count, 256)
    }

    func testRealCaptureAndFalseLiveClaimRejectedBySyntheticTool() throws {
        XCTAssertThrowsError(try SyntheticReplay.decode(fixtureData(synthetic: false))) { error in
            XCTAssertEqual(error as? TelemetryError, .notSynthetic)
        }
        XCTAssertThrowsError(try SyntheticReplay.decode(fixtureData(source: "LIVE"))) { error in
            XCTAssertEqual(error as? TelemetryError, .sourceMismatch)
        }
        let observation = try XCTUnwrap(SyntheticReplay.decode(fixtureData()).validate().first)
        XCTAssertEqual(observation.delivery, .replay)
        XCTAssertEqual(observation.packet.source, .mock)
    }

    func testMalformedAndUnknownProvenanceJSONRejected() throws {
        XCTAssertThrowsError(try SyntheticReplay.decode(Data("{".utf8)))
        XCTAssertThrowsError(try SyntheticReplay.decode(fixtureData(source: "UNKNOWN")))
    }

    func testDirectDecoderCannotBypassSyntheticValidation() throws {
        let replay = try JSONDecoder().decode(SyntheticReplay.self, from: fixtureData(source: "LIVE"))
        XCTAssertThrowsError(try replay.validate()) { error in
            XCTAssertEqual(error as? TelemetryError, .sourceMismatch)
        }
    }
}
