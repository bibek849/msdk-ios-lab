# ADR 0002: iPhone-to-RC-N3 transport observation boundary

- **Date:** 2026-11-03
- **Status:** proposed with milestone M3 of the [assigned work package](https://github.com/bibek849/msdk-ios-lab/issues/4); awaiting maintainer review.
- **Device work:** none approved. **M5 ([#6](https://github.com/bibek849/msdk-ios-lab/issues/6)) remains NOT APPROVED.**
- **Evidence:** [native access dossier](../NATIVE_ACCESS_DOSSIER.md) and [source register](../SOURCES.md). Every hardware result is NOT RUN.

This is a completed [component decision](../templates/COMPONENT_DECISION.md) under the [porting policy](../PORTING_POLICY.md). It is a design decision, not permission to run hardware.

## Requirement and scope

- **Issue / stage:** [LAB-002](https://github.com/bibek849/msdk-ios-lab/issues/2) at S0, preparing [LAB-007](https://github.com/bibek849/msdk-ios-lab/issues/6) and the H1 run in [HARDWARE_TESTING.md](../HARDWARE_TESTING.md#initial-test-matrix).
- **Required capability:** read-only observation of whether a development-signed app on an iPhone 15 Pro Max can see RC-N3 (paired with a Mini 4 Pro) as an accessory, open one session and receive bytes, in cold-start and DJI Fly–primed cohorts. Exact iOS and firmware versions are pending.
- **Component:** the iPhone-to-RC-N3 transport observation boundary, covering layers L1–L5 from the [dossier](../NATIVE_ACCESS_DOSSIER.md#4-controller-detection-is-not-an-aircraft-session):
  - accessory visibility;
  - advertised protocols;
  - one External Accessory session;
  - input-stream readiness;
  - byte counts.

  Its only dependency is Apple's public External Accessory framework.
- **Why now, and what is deferred:** S0 must establish whether a permitted transport exists before any session, telemetry or video work. Deferred:
  - message parsing and controller or aircraft meaning (L6);
  - aircraft session initialization (L7);
  - every write path;
  - telemetry mapping (LAB-008), video (LAB-009) and commands (S5+).

## Existing implementation and evidence

| Candidate | Origin and identity | Usable here? |
|---|---|---|
| DJI iOS Mobile SDK | 4.16.2, commit `071cd3e` (D3) under the DJI EULA (D4) | No. It is the last iOS release, no reviewed source lists Mini 4 Pro support, and the closed binary may not be ported or reverse engineered (§3.2). |
| DJI iOS MSDK V5 | None found (D3, D6, D11) | Unavailable |
| DJI iOS-Bridge-App | `2853d8f`, MIT, deprecated (D8) | No. Its MIT source calls DJI SDK bridge APIs and contains no External Accessory session code to reuse. Its Info.plist confirms DJI protocol names only. |
| DJI iOS sample apps | `071cd3e`, sample code MIT (D7) | Names only. They declare the protocol names; the transport itself lives in the closed SDK. |
| Android MSDK 5.18.0 | AARs under the EULA (D1, D2) | No. It is the reference track only; its Android USB host route does not apply to iOS, and porting is restricted. |
| DJI-FCC-Unlock-iOS | `000c332`, PolyForm Noncommercial (C2) | No. The license is incompatible with this MIT project, and its scope includes radio changes. Its observations are leads only. |
| dji_protocol notes | `50c71b6`, no license (C4) | No. Reference only. |
| This project's Swift core | `MSDKIOSCore` (S1) | Not needed by H1. It is kept unchanged; the observation contract is a separate M4 target. |

- **Available material:** Apple's documented API (A1, A4–A6) and DJI-published protocol names (D7). No message specification exists from any permitted source.
- **License or permission basis:**
  - Apple's public SDK is used under the owner's Apple developer agreement.
  - DJI's protocol names come from MIT-licensed sample code.
  - DJI has not granted third-party communication permission for RC-N3 (A1). This is unresolved, and the owner decides.
- **Source portability evidence:** not applicable, because no implementation is reused.
- **Build and deployment evidence:**
  - This repository's `MSDKIOSCore` type-checks against the iOS SDK (README); no External Accessory code exists yet.
  - Building the M5 probe needs Xcode and owner signing.
  - Linux CI can build only the portable M4 target.
- **Device behavior evidence:** **NOT RUN.** C2 reports RC-N3 + Neo session traffic only after DJI Fly priming; this is not evidence for Mini 4 Pro.
- **Unresolved assumptions and the smallest experiment:** whether RC-N3 advertises a reviewed protocol to a development-signed app, accepts a session and sends bytes without a write, cold versus primed. The smallest experiment is H1 as planned in [dossier §6](../NATIVE_ACCESS_DOSSIER.md#6-h1-plan-write-free-bounded-five-cold-and-five-primed-runs).

## Decision

**INVESTIGATE** the transport boundary with one bounded, write-free H1 probe after owner checkpoint A. The probe's adapter, if M5 is approved, is **IMPLEMENT MISSING CAPABILITY**: a small original Swift adapter over public External Accessory APIs. Controller and aircraft meaning (L6–L7) is **BLOCKED**. The DJI SDK route is **BLOCKED** for this combination.

- **Why this is the smallest sufficient intervention:** no reusable or rebuildable implementation exists, and the experiment needs only Apple's public API, one protocol name and passive counting. Parsing, sessions with the aircraft and writes would answer later questions before the first one is known.
- **ADAPT / PORT MINIMUM:** not applicable. No compatible core exists to adapt, and nothing permitted exists to port.
- **New original implementation:** no usable implementation exists (table above). The permitted interface is Apple's documented External Accessory framework (A4–A6). The work is original code, not a translation of SDK source.
- **Existing code retained unchanged:** `MSDKIOSCore`, the JSON v1 telemetry contract, `msdk-ios-replay` and all tooling.
- **New code, public-contract effects and dependencies:** two new targets (below). There is no change to existing products or the telemetry API, and no third-party dependency.
- **Language:**
  - Swift 6, with Swift tools 6.0, matching the [engineering standard](../ENGINEERING_STANDARD.md#language-choices-for-new-required-code).
  - Objective-C is not needed: External Accessory and `Stream` are usable from Swift.
  - No C++.
- **Alternatives considered:**
  - An Android bridge: not native, and does not answer S0.
  - Binary rehosting: deferred to LAB-012.
  - DriverKit or raw USB: not available on iPhone (A2, A3).
  - AccessorySetupKit: Bluetooth and Wi-Fi only (A8).
  - Copying C2's approach: license and scope prevent it.
  - Opening every advertised protocol: more intervention than one-protocol runs need.

## Minimum patch plan for eventual #6 (M5, not approved)

M4, which is authorized in #4, comes first and is host-only. M5 adds the Apple-only pieces only after explicit approval.

| Milestone | Proposed path | Responsibility |
|---|---|---|
| M4 | `Sources/MSDKIOSProbeSupport/` | Portable observation contract and reducer: injected logical time, explicit session identity, synthetic provenance, and separate facts for L1–L5. Aircraft readiness is always **unknown**. Bounds: 262,144 bytes, 256 events, 128-byte session IDs, 60-second windows. |
| M4 | `Tests/MSDKIOSProbeSupportTests/` and `fixtures/synthetic-probe/` | A valid lifecycle; the exact timeout boundary; disconnect; wrong-session and out-of-order events; invalid clocks; duplicate close; post-close input; overflow; input bounds. A rejected event leaves prior state intact. |
| M4 | `Package.swift` | Add the library and test targets only. Tools stay at 6.0 with no dependencies; existing products are unchanged. |
| M5 | `Sources/MSDKIOSAccessoryProbe/`, compiled only `#if canImport(ExternalAccessory)` | An adapter that maps `EAAccessoryManager` connect/disconnect, `protocolStrings`, one `EASession` and input-stream events to M4 observations. It opens no output stream, writes nothing, discards payload, never reads `serialNumber`, and enforces the 60-second window. |
| M5 | `Apps/AccessoryProbe/` | A minimal foreground SwiftUI shell with a Start button and a run summary. Its Info.plist declares only the reviewed names and no background mode. The maintainer builds and signs it in Xcode; CI does not. |
| M5 | `experiments/H1-NATIVE-TRANSPORT-PROBE.json` | A `read_only_hardware` S0 descriptor: 10 repetitions, 60 seconds, prerequisites taken from the [owner checklist](../NATIVE_ACCESS_DOSSIER.md#owner-checklist). |
| M5 | Adapter tests | Mapping tests through a protocol-typed fake event source on host. The owner runs `xcodebuild` against `generic/platform=iOS`; it is NOT RUN in Linux CI. |

**Interfaces (proposed names; M4 review may refine them):**
- `ProbeObservation` is a versioned enum of L1–L5 facts plus close, detach and window-elapsed events.
- `ProbeRunState` is the reducer output.
- `AccessoryEventSource` is the seam between the Apple adapter and the portable reducer.

## Verification and handoff

- **Acceptance criteria:**
  - M4 host tests pass on Linux with Swift 6.0.3 and 6.x.
  - The M5 adapter compiles for iOS in the owner's Xcode.
  - H1 records L1–L5 per run with a clean close and no writes.
  - Nothing reports aircraft readiness.
- **Source revision and commands:** for this documentation change, `python3 tools/check_repository.py` and `git diff --check`. M4 and M5 record their own.
- **Regression tests:** for M4 and M5 as above. The existing Swift tests (16 on this base) stay green.
- **Results and limitations:** documentation only; no build or hardware artifact.
- **Performance evidence:** none claimed.
- **Hardware test needed:** owner-run H1. The open question is whether RC-N3 reaches L2–L5 for a development-signed probe in cold versus primed cohorts.
- **Next prerequisite:** owner checkpoint A (inventory, rights decisions, M5 approval). Stop if a write, handshake semantics or an unavailable permission becomes necessary.
- **Maintainer review:** pending.
