# Swift research foundation

This package is original, project-owned diagnostic code. It contains no DJI SDK,
DJI transport implementation, aircraft commands, video decoder or UI. The
`MSDKIOSCore` library declares iOS 16 and macOS 13 as engineering deployment
floors; these declarations are not successful device-build or hardware evidence.
The Swift tools minimum is 6.0. There are no third-party package dependencies.

## Run without hardware

From the repository root with Swift 6.0 or later:

```sh
swift test
swift run msdk-ios-replay fixtures/synthetic-telemetry-v1.json
```

The command accepts at most one file path, reads at most 262,145 bytes and rejects
fixtures larger than 262,144 bytes or 256 events. It has no sockets, device
discovery, credentials or external SDK registration. `--help` describes usage.
An invalid fixture exits with status 1 and prints its rejection to stderr.

The checked-in fixture is entirely synthetic. Its three samples demonstrate
unknown measurements, a known zero altitude, and a negative relative altitude.
This is a contract example, not a physical aircraft trace.

## Contract v1

`TelemetryPacket` is a `Codable` value with:

| Field | Meaning |
| --- | --- |
| `schemaVersion` | Must equal 1 |
| `sessionID` | Exact session identity, 1–128 UTF-8 bytes, not all whitespace |
| `sequence` | Unsigned 64-bit, strictly increasing within the session; gaps allowed |
| `source` | Declared observation origin: `MOCK`, `REPLAY` or `LIVE` |
| `sourceTimestampUnixMilliseconds` | Optional source wall-clock label, nonnegative if present |
| `altitudeRelativeMeters` | Optional finite relative altitude in meters; negative is valid |
| `batteryPercent` | Optional finite percentage in [0, 100] |

Unknown values encode as `null`. They do not become zero. The decoder also treats
absent optional measurement fields as unavailable. Unknown enum values, malformed
types and unsigned integer overflow fail decoding. Extra JSON fields are ignored
for additive compatibility; unknown schema versions are rejected.

`TelemetrySession.accept` takes `receivedAtMilliseconds` and `nowMilliseconds`
from the same caller-owned monotonic clock. It rejects `now < receivedAt`, local
ages above 1,000 ms by default, wrong sessions, duplicate/older sequences,
unsupported schema versions and invalid measurements. Rejected samples do not
advance the sequence. The threshold is a diagnostic policy, not an aircraft
response-time guarantee. The caller must supply a monotonic clock consistently;
the library does not acquire wall time or establish clock synchronization.

`ValidatedObservation.localAgeMilliseconds` means **time since local receipt**.
It does not establish aircraft sample freshness, upstream transport delay or
camera-to-display latency. A packet's source timestamp is retained independently
and is never subtracted from the receiver clock. Upstream freshness is unknown
until a separately specified measurement mechanism establishes it.

`ValidatedObservation.delivery` comes from the receiver/session, independently of
the packet's declared source. Replay remains `REPLAY` even when the original
recording declares `LIVE`. Source labels are metadata, not proof of authenticity
or a hardware validation claim. This package has no authenticated live receiver.

`SyntheticReplay.decode` additionally requires `synthetic: true` and only `MOCK`
packet sources. `validate()` uses `delivery: REPLAY`; its event time offsets
simulate a monotonic receiver clock deterministically. They are test inputs, not
timing measured on a phone. The CLI reports both labels, unavailable measurements,
and the absence of native transport/hardware validation.

## Extension boundary

Keep the decoder and validator usable without connected hardware. A future
transport may supply observations only after its own session/authentication and
capability gates. Add explicit source-age semantics before advertising freshness
from the aircraft. Do not reuse this telemetry validator as a command authority
system: it does not implement approvals, revocation, leases or RC takeover.

`ResearchCapabilities` intentionally reports native iOS transport, aircraft
commands and hardware validation as unavailable. Change these claims only with
implementation and corresponding device evidence at the appropriate stage.
