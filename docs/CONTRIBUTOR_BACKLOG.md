# Contributor backlog

Tasks are intentionally small. Choose one, propose an approach, and attach reproducible evidence. **Ready** means work can start with original synthetic material; **gated** means prerequisites must be resolved first. No task promises a device compatibility result.

| ID | Task and deliverable | Owner role | Dependency / state | Acceptance |
|---|---|---|---|---|
| [LAB-001](https://github.com/bibek849/msdk-ios-lab/issues/1) | Record permission/provenance boundaries for the SDK, sample and independently authored code | Maintainer with qualified licensing input | S0 / ready for research | Exact sources, dates and unresolved permission questions; no claim that sample licensing covers SDK binaries |
| [LAB-002](https://github.com/bibek849/msdk-ios-lab/issues/2) | Build a native transport and initialization dossier for iPhone 15 Pro Max | Apple-platform contributor + hardware maintainer | S0 / ready for research | Public API/entitlement requirements, actual iOS build, independent cold-start hypothesis and explicit GO/BLOCKED/NO-GO criteria; USB-C alone is insufficient |
| [LAB-003](https://github.com/bibek849/msdk-ios-lab/issues/3) | Complete local device inventory | Hardware maintainer | S0 / pending target details | iOS model/OS/signing, aircraft/controller firmware and cable route recorded; sensitive identities private |
| [LAB-004](https://github.com/bibek849/msdk-ios-lab/issues/4) | Extend original Swift telemetry replay boundary tests | Swift contributor | S1 / ready | Deterministic tests for malformed input, ordering, sessions, unavailable values and freshness; no SDK or hardware dependency |
| [LAB-005](https://github.com/bibek849/msdk-ios-lab/issues/5) | Design versioned video metadata fixtures | Protocol/video contributor | S1 / ready | Synthetic frame identity, timestamps/clock basis, codec/dimensions, drops and missing-data cases; replay cannot claim live status |
| LAB-006 | Specify an independent Android 5.18.0 read-only reference bench | Android contributor | S2 / implementation gated on LAB-001 | Reproducible version pins; no flight executor; registration and controller/aircraft states distinct; reviewable local test procedure |
| [LAB-007](https://github.com/bibek849/msdk-ios-lab/issues/6) | Implement the minimal permitted native iOS connection probe | Apple-platform contributor | S3 / gated on LAB-001–003 | Exact public transport route; no relay; bounded diagnostics and clean close; maintainer executes H1 with five cold and five separately recorded primed runs |
| LAB-008 | Map one native telemetry field end to end | Swift/protocol contributor | S3 / gated on LAB-007 and source permissions | Unit, absence, sequence and freshness semantics plus synthetic tests and local H3 evidence |
| LAB-009 | Propose a bounded iOS video pipeline | Video contributor | S4 / design research can start; hardware integration gated on S3 | Separate ingress/decode/presentation metrics, queue/drop policy and stream recovery; no unmeasured FPS claim |
| LAB-010 | Design command authority and fault tests before adding actuation | Runtime contributor | S5 / synthetic design ready; hardware actions gated | Fresh deliberate grant, bounded scope/expiry, replay/session rejection, latched RC takeover and explicit rearm tested in isolation |
| LAB-011 | Optional reference bridge contract | Networking contributor | Reference track / synthetic design ready | Explicit Android dependency, authenticated sessions, read-only first, bounded queues; never reported as a native port |
| LAB-012 | Assess literal binary rehosting as a bounded alternative spike | Runtime/Apple-platform contributor | S0 / SDK analysis gated on LAB-001 | Document format/ABI/runtime/signing barriers and a falsifiable small experiment; general precedents are not DJI-on-iPhone evidence; no binaries added to repository |

The initial Swift foundation may already implement part of LAB-004; inspect the source and [test results](TEST_RESULTS.md) before proposing duplicate work. A successful synthetic test does not close a hardware task.

## What to put in a PR

- The task ID, one concrete hypothesis and what the patch changes.
- Exact checks run and their output, with unrun checks explicitly named.
- Sources and licenses for any imported material; prefer small original implementation.
- For a hardware request: source commit, artifact hash or reproducible build, prerequisite stage, maximum run duration, expected observation and abort conditions.
- Whether any result or fixture has SDK, privacy or redistribution restrictions. Keep restricted material out of the PR.

The maintainer returns a run status or a synthetic reproduction. Contributors can complete useful work without buying a drone or being given access to the hardware owner's accounts.
