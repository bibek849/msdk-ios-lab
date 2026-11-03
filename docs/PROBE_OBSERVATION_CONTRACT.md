# Probe observation contract v1

- **Date:** 2026-11-03.
- **Scope:** milestone M4 of the [assigned work package](https://github.com/bibek849/msdk-ios-lab/issues/4), based on `0fbc297`.
- **Status:** proposed design with a host-only implementation in `Sources/MSDKIOSProbeSupport/`.
- **Device work:** none. **Software only:** no hardware, iOS build, accessory API, network or credential is used. M5 ([#6](https://github.com/bibek849/msdk-ios-lab/issues/6)) is **NOT APPROVED**.

**Design inputs:**
- The native access dossier and ADR 0002 proposed in [PR #16](https://github.com/bibek849/msdk-ios-lab/pull/16).
- The maintainer's [M2–M4 design guidance](https://github.com/bibek849/msdk-ios-lab/pull/16#issuecomment-6596777808).
- The public stream concepts in Apple's [Stream Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Streams/Articles/ReadingInputStreams.html): open, bytes available, read result, error and end.
- Apple's [External Accessory](https://developer.apple.com/library/archive/featuredarticles/ExternalAccessoryPT/Introduction/Introduction.html) concepts of accessory visibility, advertised protocols and sessions.

This contract is project-owned. It defines no DJI mechanism.

## Question

The contract answers whether a probe's observations can be recorded and reduced so that the following stay independent facts:
- accessory visibility;
- advertised protocols;
- session creation;
- input-stream state;
- output-stream state;
- the first successful nonzero read;
- separately defined synthetic readiness observations;
- the run's end.

Each fact must be tied to a run and session identity under injected logical time. On top of that:
- No stream event or byte receipt may set aircraft readiness, initialization or telemetry validity.
- A late or invalid observation must never corrupt prior state.

If the answer is yes, an H1 run record cannot conflate transport layers with aircraft readiness.

## Non-goals

- No accessory enumeration, session or stream is performed. The code only reduces recorded or synthetic observations.
- There is no transmitter, write path, initialization packet, protocol authentication, handshake or readiness dispatcher.
- There are no vendor identifiers, packet data, binary excerpts or inferred handshake semantics. Fixtures use `org.example.synthetic.*` protocol names.
- The telemetry contract, JSON v1 fixtures, `ResearchCapabilities` and existing package products are unchanged. Nothing here grants command authority.

## Identity, provenance and time

- **Run identity:**
  - A run has a `runID`: 1–128 UTF-8 bytes, not all whitespace (the same rule as telemetry session IDs).
  - Its cohort label is `COLD`, `PRIMED` or `UNSPECIFIED`, fixed when the run is created.
  - Every observation carries a `runID`. An observation from another run is rejected, which is how a late callback from an old run is handled. No observation can change the cohort.
- **Sessions:** a run has at most one session, identified by a `sessionID` that follows the same length rule. This matches H1's one-protocol-per-run plan.
- **Provenance:** the run records its origin and delivery as the existing `Provenance` type. Synthetic fixtures have origin `MOCK` and are replayed with delivery `REPLAY`. A future adapter would use origin `LIVE`.
- **Time:**
  - `atMilliseconds` comes from the caller's monotonic clock.
  - A run starts at `startedAtMilliseconds` and has a window of 1–60,000 ms. `start + window` must not overflow `UInt64`.
  - An observation is accepted only if `start ≤ at ≤ start + window` and `at` is not earlier than the previous accepted observation. Equal times are allowed.

## Independent facts

| Fact | Initial value | Set only by | Never set by |
|---|---|---|---|
| Accessory visible (ID, time) | none | `ACCESSORY_VISIBLE` | any other event |
| Advertised protocols | not observed (`nil`) | `PROTOCOLS_ADVERTISED`. The latest list wins, and an empty list is a valid observation, for example before authentication. | session or stream events |
| Session (ID, protocol, time) | none | `SESSION_CREATED` | stream events |
| Session creation failures | 0 | `SESSION_CREATION_FAILED` | — |
| Input-stream state | `NOT_REQUESTED` | input stream events | output stream events |
| Output-stream state | `NOT_REQUESTED` | output stream events | input stream events |
| Bytes-available events | 0 | `BYTES_AVAILABLE` | — |
| First successful read time | none | the first `READ_COMPLETED` with `byteCount > 0` | `BYTES_AVAILABLE`, zero-byte reads, `READ_FAILED` |
| Successful reads and bytes read | 0 | `READ_COMPLETED` with `byteCount > 0` | — |
| Zero-byte reads and failed reads | 0 | `READ_COMPLETED` with `byteCount == 0`, and `READ_FAILED` | — |
| Blocked write attempts | 0 | `WRITE_ATTEMPTED`; nothing is ever transmitted | — |
| Aircraft ready, initialization complete, telemetry valid | `unknown` each | `SYNTHETIC_READINESS` in a `MOCK` run only, one fact at a time | every session, stream, read and write event |
| End reason and time | none | close, detach, operator stop or window expiry | — |

Two policy flags mark H1 stop conditions:
- `OUTPUT_STREAM_ACTIVITY`, set by any accepted output-stream event;
- `WRITE_ATTEMPT_BLOCKED`, set by any recorded write attempt.

The flags are facts only. The model does not stop the run, transmit anything, or change any other fact because of them.

## Stream states

Each stream follows the same state machine independently:
- `NOT_REQUESTED` → `OPEN` on `STREAM_OPENED`, or → `ERROR` on `STREAM_ERROR` (opening failed).
- `OPEN` → `ERROR` or `END`.
- `ERROR` and `END` are final for that stream.

An event for one stream never changes the other stream. `BYTES_AVAILABLE`, `READ_COMPLETED` and `READ_FAILED` require the input stream to be `OPEN`.

## Events (v1)

Every observation has `runID`, `atMilliseconds` and `kind`. The "Requires" column lists checks beyond run identity, the run not having ended, and time.

| `kind` | Fields | Requires | Effect |
|---|---|---|---|
| `ACCESSORY_VISIBLE` | `accessoryID` (UInt64) | No accessory recorded yet | Records the accessory and the time |
| `PROTOCOLS_ADVERTISED` | `accessoryID`, `names` | The same visible accessory; a valid list | Replaces the advertised list |
| `SESSION_CREATED` | `sessionID`, `protocolName` | No session yet; a list observed that contains the name; a valid ID | Records the session, protocol and time |
| `SESSION_CREATION_FAILED` | `protocolName` | No session yet; a list observed that contains the name | Increments failures |
| `STREAM_OPENED` | `sessionID`, `stream` (`INPUT`/`OUTPUT`) | The current session; that stream is `NOT_REQUESTED` | That stream becomes `OPEN` |
| `STREAM_ERROR` | `sessionID`, `stream` | The current session; that stream is `NOT_REQUESTED` or `OPEN` | That stream becomes `ERROR` |
| `STREAM_END` | `sessionID`, `stream` | The current session; that stream is `OPEN` | That stream becomes `END` |
| `BYTES_AVAILABLE` | `sessionID` | The current session; input `OPEN` | Counts the event only |
| `READ_COMPLETED` | `sessionID`, `byteCount` (UInt64) | The current session; input `OPEN`; the total does not overflow | Nonzero: counts the read and bytes and sets the first read time once. Zero: counts a zero-byte read. |
| `READ_FAILED` | `sessionID` | The current session; input `OPEN` | Counts a failed read |
| `WRITE_ATTEMPTED` | `sessionID` | The current session | Counts a blocked attempt and sets `WRITE_ATTEMPT_BLOCKED`; transmits nothing |
| `SYNTHETIC_READINESS` | `fact`, `value` (Bool) | Origin `MOCK` | Records that one fact as synthetically reported |
| `SESSION_CLOSED` | `sessionID` | The current session | Ends the run (`SESSION_CLOSED`) |
| `ACCESSORY_DETACHED` | `accessoryID` | The same visible accessory | Ends the run (`ACCESSORY_DETACHED`) |
| `OPERATOR_STOPPED` | — | — | Ends the run (`OPERATOR_STOPPED`) |

`fact` is one of `AIRCRAFT_READY`, `INITIALIZATION_COMPLETE` or `TELEMETRY_VALID`. These are labels for exercising this model, not observations of any device.

## Ending a run

- `SESSION_CLOSED`, `ACCESSORY_DETACHED` and `OPERATOR_STOPPED` end the run at the observation's time.
- **Window expiry:**
  - Expiring the window ends the run with `WINDOW_ELAPSED` at exactly `start + window`, whenever it is called. The fixture runner calls it after the last observation if the run is still open.
  - An observation later than the window end is **rejected without ending the run**, because a rejected observation never changes state.
  - An observation exactly at the window end is accepted.
- **State at the end:** ending keeps the last independent observations. Stream states, counts and readiness values are not rewritten; for example, a detach does not mark an open stream ended.
- **After the end:** every observation is rejected as `runEnded`, including a duplicate close. The end reason and time never change.

## Rejection order and state

Checks run in this order, and the first failure is the reason:
1. run identity (`wrongRun`);
2. the run has ended (`runEnded`);
3. time (`beforeStart`, `outOfOrder`, `afterWindow`);
4. the event's own requirements.

A rejected observation leaves the state exactly as it was: the reducer applies each observation to a copy and commits only on success. The fixture runner reports each rejection with the index of the observation. Rejections are bounded by the event limit.

## Bounds

- **Fixture size:** at most 262,144 bytes and 256 events, the same constants as `SyntheticReplay`.
- **Identities:** `runID` and `sessionID` are at most 128 UTF-8 bytes each.
- **Window:** 1–60,000 ms.
- **Protocol lists:** at most 32 names. Each name is 1–128 UTF-8 bytes with no whitespace or control characters, and there are no duplicates.
- **Overflow:** byte totals use checked `UInt64` addition; an overflow is rejected.
- **Retention:** only counts, identifiers and times are kept. Payload is never kept.

These are diagnostic input limits, not packet sizes or measured device performance.

## Fixture format v1

```json
{
  "schemaVersion": 1,
  "synthetic": true,
  "source": "MOCK",
  "runID": "synthetic-run-1",
  "cohort": "UNSPECIFIED",
  "startedAtMilliseconds": 1000,
  "windowMilliseconds": 60000,
  "events": [
    {"runID": "synthetic-run-1", "atMilliseconds": 1000, "kind": "ACCESSORY_VISIBLE", "accessoryID": 1},
    {"runID": "synthetic-run-1", "atMilliseconds": 1010, "kind": "PROTOCOLS_ADVERTISED", "accessoryID": 1, "names": ["org.example.synthetic.alpha"]}
  ]
}
```

The fixture is rejected as a whole in these cases:

| Condition | Error |
|---|---|
| More than 262,144 bytes, or more than 256 events | `tooLarge`, `tooManyEvents` |
| `schemaVersion` other than 1 | `unsupportedSchema` |
| `synthetic` is not `true` | `notSynthetic` |
| `source` other than `MOCK` | `sourceMismatch` |
| An invalid run ID or window | `invalidRun`, `invalidWindow` |

Any unknown `kind`, `stream`, `fact` or `cohort`, a missing field, a wrong type, or a negative or larger-than-`UInt64` number fails decoding. Extra fields are ignored, as in telemetry v1. Individual observations that fail the rules above are rejected and reported, while the rest of the run continues.

## Expected semantics for the required cases

The tests assert these outcomes.

| Case | Expected outcome |
|---|---|
| Valid lifecycle (visible → protocols → session → input open → bytes available → read → close) | All layers recorded with their times. Output `NOT_REQUESTED`. Readiness `unknown`. End `SESSION_CLOSED`. No rejections. |
| Input opens while output is not requested; then the output open fails | Input `OPEN` throughout. Output goes from `NOT_REQUESTED` to `ERROR`. |
| Output opens without input | Output `OPEN`, input `NOT_REQUESTED`, `OUTPUT_STREAM_ACTIVITY` set, no read facts |
| Stream opens, no bytes, window expires | `WINDOW_ELAPSED` at `start + window`. Input still `OPEN`. No first read; zero bytes. |
| Bytes arrive with readiness unknown | Bytes counted; all three readiness facts stay `unknown` |
| Bytes available, then a zero-byte read and a failed read | No first read time; one available event, one zero-byte read, one failed read |
| Close, then late callbacks | Each late callback is rejected as `runEnded`; the state equals the state at close |
| Detach, then late callbacks | End `ACCESSORY_DETACHED`; late callbacks are rejected and the stream states are unchanged |
| A late callback from another run | Rejected as `wrongRun`; cohort and state unchanged |
| Exact window boundary | An observation at `start + window` is accepted; one 1 ms later is rejected as `afterWindow` with the state intact; expiry ends at `start + window` |
| Out-of-order, before-start, or overflowing window | `outOfOrder` or `beforeStart`; creating a run whose window overflows or exceeds 60,000 ms fails with `invalidWindow` |
| Wrong session | `wrongSession`, state intact |
| Duplicate close | The second close is rejected as `runEnded`; the end reason and time are unchanged |
| Write attempt | One blocked attempt, `WRITE_ATTEMPT_BLOCKED` set, no other fact changed |
| Synthetic readiness | Sets only the named fact in a `MOCK` run; rejected as `syntheticObservationNotAllowed` in a `LIVE` run |
| Empty, then populated, protocol list | Both accepted. A session is rejected before the name is advertised and accepted after. |
| Byte-total overflow | `overflow`, state intact |
| Envelope and bounds | `tooLarge`, `tooManyEvents`, `notSynthetic`, `sourceMismatch`, `unsupportedSchema`, `invalidRun`, and decoding errors for malformed values |

## What this cannot establish

- Accessory access, session behavior, OS or accessory traffic, or timing on any real device.
- Any controller or aircraft meaning. Readiness values in fixtures are synthetic labels.
- That M5 will be approved, or that any H1 run is permitted.

## Relationship to M5 (not approved)

A future adapter would map External Accessory and Foundation stream callbacks to these observations, with origin `LIVE`, after explicit approval in #6. That mapping, its tests and any device run belong to M5. M5 needs no change to this contract unless a reviewed decision says otherwise.
