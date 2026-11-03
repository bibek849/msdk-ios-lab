# ADR 0003: M5 ControllerProbe components

- **Date:** 2026-11-03
- **Status:** implementation approved by the owner in [#4](https://github.com/bibek849/msdk-ios-lab/issues/4) and [#6](https://github.com/bibek849/msdk-ios-lab/issues/6). Session activation is pending a permitted protocol and the owner's preflight. Hardware is **NOT RUN**.
- **Scope:** the first source handoff for the planned November 4 owner checkpoint.
- **Related records:**
  - The transport-boundary decision (ADR 0002) and the native access dossier are under review in [PR #16](https://github.com/bibek849/msdk-ios-lab/pull/16).
  - The observation contract is [PROBE_OBSERVATION_CONTRACT.md](../PROBE_OBSERVATION_CONTRACT.md).

These are [component decisions](../templates/COMPONENT_DECISION.md) under the [porting policy](../PORTING_POLICY.md). Each new boundary is recorded with why it is needed. None of them is a port of vendor source.

## Components

| Component | Need | Available source and permission | Decision | Retained or changed |
|---|---|---|---|---|
| `MSDKIOSCore` telemetry core | No telemetry in this slice; its `Provenance` labels the run `LIVE` | Original project code, MIT | **REUSE** unchanged | JSON v1, telemetry API and `ResearchCapabilities` are unchanged |
| `MSDKIOSProbeSupport` observation model (M4) | One reducer for every run fact | Original project code, MIT | **REUSE**, plus two small changes | `OPERATOR_STOPPED` is replaced by `RUN_STOPPED` with an explicit reason, so budget, stream and background stops are named. `apply` uses typed `throws(ProbeError)`. |
| Run controller (`MSDKIOSAppleTransport`, portable) | The activation gate, the 60 s / 256-entry / 4 KiB / 1 MiB budgets, the stop policy and cleanup | No existing implementation | **IMPLEMENT MISSING CAPABILITY** (original Swift) | New; host-tested on Linux |
| External Accessory binding (`ExternalAccessoryProbe`, Apple-only) | Turn public-API callbacks into observations | Apple's documented External Accessory and `Stream` APIs. No usable DJI implementation: the iOS SDK 4.16.2 is closed and EULA-restricted, no iOS V5 distribution was identified, and the Bridge App only calls SDK APIs. | **IMPLEMENT MISSING CAPABILITY** over the public API. There is nothing compatible to adapt or port. | New; Apple compilation is **NOT RUN** |
| `ControllerProbe` app, Xcode project and `build-device.sh` | Signed device installation and a run record for the owner | Apple tooling on the owner's Mac | **IMPLEMENT MISSING CAPABILITY** | New. Committed defaults are BLOCKED with no declared protocol. |
| Vendor SDK, private IPA, community code | — | Restricted, unavailable or license-incompatible | **BLOCKED** as a source | Nothing is imported or derived |
| Output stream, writes, handshakes, payload parsing | Not needed to observe L1–L5 | — | **DEFER**; deliberately not implemented | No API exists for them |

The language is Swift 6 with tools 6.0. There is no new dependency or toolchain. The two library products added to `Package.swift` exist only so that the app can link the package.

## Activation and budgets

- **Activation gate:** `ProbeRunProfile` reads the build values in `Info.plist`.
  - A missing mode means BLOCKED, and an unrecognized mode is blocked as `UNKNOWN_MODE`.
  - `ENUMERATION_ONLY` and `SESSION_OBSERVATION` both need a full 40-character source SHA and a permission basis.
  - A session also needs exactly one protocol name, which the app must declare.
  - The activation label never contains the protocol name.
- **One run at a time:** `ProbeRunController` owns one run with `LIVE` provenance and a 60-second window.
- **Reads:** the next read length is `min(4 KiB, remaining of 1 MiB)`. Reaching 1 MiB stops the run (`READ_BUDGET`).
- **Log:** the log keeps every distinct event, every rejection, and the first entry of each repeated read-path event. Every observation still updates the counters. When 255 entries are retained, the stop entry takes the last slot (`EVENT_BUDGET`).
- **Other stops:**
  - an input-stream error or end (`STREAM_ERROR`, `STREAM_END`);
  - disconnect;
  - the operator's Stop (`OPERATOR`);
  - the app leaving the foreground (`APP_BACKGROUND`);
  - the window ending.
- **After a run ends:** callbacks are counted but never applied or retained. A new run needs an explicit Start.
- **Readiness:** aircraft readiness, initialization and telemetry stay `UNKNOWN`. The reducer rejects synthetic readiness observations in `LIVE` runs.

## Threading, ownership and cleanup

`ExternalAccessoryProbe` is `@MainActor`:
- Accessory notifications are observed on the main queue, and only the session's input stream is scheduled on the main run loop.
- The `nonisolated` `stream(_:handle:)` callback passes Sendable values (the stream's identity and the raw event) into `MainActor.assumeIsolated`.
- A run owns at most one session and one cancellable expiry task. Ending the run for any reason cancels the task, clears the delegate, closes and unschedules the input stream, releases the session, removes the observers and unregisters accessory notifications.
- A stale stream or a disconnect from another accessory is counted as a late callback.
- Concurrency diagnostics are not suppressed: there is no `@unchecked Sendable` and no `@preconcurrency`.

## Verification layers

| Layer | Evidence |
|---|---|
| Portable logic | 55 tests on Linux with Swift 6.4.2 and 6.0.3 ([test results](../TEST_RESULTS.md)) |
| Apple-only binding | Type-checked on Linux against local stand-ins for the External Accessory and Combine names it uses. This checks Swift typing only and is **not** an Apple build. |
| Xcode project and app | Structurally checked: object references, scheme XML, Info.plist parsing and shell syntax. Opening, compiling, signing and installing are **NOT RUN**. |
| Device, RC-N3, Mini 4 Pro | **NOT RUN**; owner H0 and H1 |

## Known risks for H0

- The project file is hand-written. In particular, the local-package product dependency format has never been opened in Xcode. The [README](../../apps/ios/ControllerProbe/README.md) gives fallbacks.
- The first real compile of `ExternalAccessoryProbe.swift` happens on the owner's Mac.
- Whether `connectedAccessories` lists an accessory whose protocol the app does not declare is not documented. The enumeration profile can declare the reviewed name without opening a session.
- How iOS treats a development-signed app without an MFi PPID remains UNKNOWN (dossier in PR #16).
