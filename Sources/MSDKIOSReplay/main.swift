import Foundation
import MSDKIOSCore

func run() throws {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments == ["--help"] {
        print("Usage: swift run msdk-ios-replay [synthetic-fixture.json]")
        print("Default: fixtures/synthetic-telemetry-v1.json. No hardware or network access.")
        return
    }
    guard arguments.count <= 1 else {
        throw NSError(domain: "MSDKIOSReplay", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Expected at most one fixture path; use --help."])
    }
    let path = arguments.first ?? "fixtures/synthetic-telemetry-v1.json"
    let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
    defer { try? handle.close() }
    let data = try handle.read(upToCount: SyntheticReplay.maximumBytes + 1) ?? Data()
    let observations = try SyntheticReplay.decode(data).validate()
    print("MSDK iOS Lab — synthetic telemetry replay")
    print("delivery=REPLAY recordedSource=MOCK; no DJI SDK, USB, video or aircraft commands")
    print("nativeIOSTransport=UNAVAILABLE hardwareValidated=false")
    for observation in observations {
        let sample = observation.packet
        let altitude = sample.altitudeRelativeMeters.map { String($0) } ?? "UNAVAILABLE"
        let battery = sample.batteryPercent.map { String($0) } ?? "UNAVAILABLE"
        print("sequence=\(sample.sequence) localAgeMs=\(observation.localAgeMilliseconds) altitudeRelativeMeters=\(altitude) batteryPercent=\(battery)")
    }
    print("Accepted \(observations.count) synthetic samples. Source freshness remains unknown.")
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("Replay rejected: \(error)\n".utf8))
    exit(1)
}
