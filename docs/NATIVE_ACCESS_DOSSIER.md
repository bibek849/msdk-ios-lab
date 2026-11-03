# Native access dossier: iPhone 15 Pro Max → RC-N3 → Mini 4 Pro

Research checkpoint: **2026-11-03**, base `0fbc297df3c5db950efafa1aeb7ca05a64c5af1b`. This is milestone M2 of the [assigned work package](https://github.com/bibek849/msdk-ios-lab/issues/4), recorded for [LAB-002](https://github.com/bibek849/msdk-ios-lab/issues/2). The M3 component decision is [ADR 0002](decisions/0002-native-transport-component.md). Only public sources were used. **Every hardware observation is NOT RUN.** Nothing here is legal advice or a grant of permission to use DJI material, and nothing here approves M5, device installation or any physical test.

Evidence labels:

| Label | Meaning |
|---|---|
| **DOC** | A dated primary Apple or DJI source in the [source register](SOURCES.md) |
| **REPORT** | A community author's report; not reproduced by this project |
| **HYPOTHESIS** | A proposed explanation that a bounded observation could falsify |
| **UNKNOWN** | Not established by any reviewed source |
| **OBSERVED** | A project hardware result. There are none yet. |

## Answer in brief

1. **Route.** The candidate public API surface for the proposed wired-accessory observation includes Apple's External Accessory framework (`EAAccessoryManager`, `EAAccessory`, `EASession`) and the session's Foundation streams. Through these, an app exchanges bytes with an MFi accessory over a protocol the app declares and the accessory advertises. This is not an exhaustive list of the APIs involved. Declarations, imports and available callbacks do not establish that an independently signed app can access the real combination. Under the cited constraints, raw USB, DriverKit and AccessorySetupKit are not candidates for this wired observation on the iPhone target. **DOC** [A1–A6, A8](SOURCES.md#official-apple-sources)
2. **What DJI publishes.** DJI publishes accessory protocol *names* in the sample apps of iOS SDK 4.16.2, the latest iOS SDK identified. The sources reviewed on 2026-11-03 contain no payload specification, no official iOS V5 distribution and no statement that RC-N3 exposes those names to third-party apps. **DOC** [D3, D6, D7, D11](SOURCES.md#official-dji-sources)
3. **Permission.** Apple states that the accessory manufacturer decides which third-party apps may communicate with its accessory. DJI's published App Store route runs through an MFi application to DJI. Neither source says how a development-signed, undistributed app is treated. **DOC** A1, D9; development-build treatment is **UNKNOWN**.
4. **Layers.** Accessory visibility, session creation, stream state, byte receipt, controller meaning and aircraft communication are separate facts. A probe without application-level writes can observe the first four. It cannot establish aircraft communication without protocol meaning, and no reviewed source provides that meaning under a documented permission. **DOC** A4, A6; the rest is **HYPOTHESIS**.
5. **Status.** No reviewed public source gives a NO-GO for the proposed External Accessory observation. A bounded probe is **BLOCKED** on the [owner checklist](#owner-checklist) and on the [rights questions](#unresolved-rights-and-publication-questions). It becomes **GO-for-a-proposed-probe** when those items are documented. Two questions stay open regardless: whether DJI grants manufacturer access to a third-party app, and whether the real combination behaves as documented. Approving M5 remains a separate owner decision at checkpoint A.

**"No application-level writes"** means the app never sends bytes on an output stream. It does **not** mean zero OS or accessory traffic, or zero state effects. Session creation and stream operations involve the OS and the accessory. Whether those operations are permitted, and what they do on the target, are owner-reviewed M5/H1 questions. The synthetic M4 code performs neither.

## 1. What a normally provisioned iPhone app can access

### Apple platform facts (DOC)

- **Supported connections.** The External Accessory framework manages connections to MFi accessories. Apple's overview names Lightning, 30-pin and Bluetooth connections; the reviewed pages do not mention USB-C ([A1, A4](SOURCES.md#official-apple-sources)). Whether the iPhone 15 Pro Max presents RC-N3 to apps the same way over USB-C is therefore an observation to make, not an assumption.
- **Declaring protocols.** An app declares the protocols it supports in the `UISupportedExternalAccessoryProtocols` Info.plist key, as reverse-DNS strings ([A5](SOURCES.md#official-apple-sources)).
- **Visibility.** An accessory is not visible to the framework until the system has connected it and made it ready. An accessory that is connected but not yet authenticated reports an empty `protocolStrings` list. Connection notifications start only after the app calls `registerForLocalNotifications`, and they arrive once the accessory is connected, authenticated and ready ([A4, A6](SOURCES.md#official-apple-sources)).
- **Sessions.**
  - `EASession(accessory:forProtocol:)` may return `nil`, and only one session can exist at a time for a given accessory and protocol ([A4](SOURCES.md#official-apple-sources)).
  - Apple's archived guide says that opening a session on a protocol already in use closes the existing session. It does not say whether this applies across apps ([A6](SOURCES.md#official-apple-sources)).
  - `EASession` does not interpret or format data. The manufacturer must share the protocols.
- **Manufacturer control.** Apple states that the manufacturer of an MFi accessory decides which third-party apps may communicate with it ([A1](SOURCES.md#official-apple-sources)).
- **Not candidates for this wired observation on the iPhone target, under the cited constraints:**
  - **Raw USB:** Apple DTS states that general raw-USB interface access is unavailable on iOS ([A3](SOURCES.md#official-apple-sources)).
  - **DriverKit:** USBDriverKit and DriverKit are documented for Macs and M-series iPads, not iPhone ([A2](SOURCES.md#official-apple-sources)).
  - **AccessorySetupKit:** documented for Bluetooth and Wi-Fi accessory discovery ([A8](SOURCES.md#official-apple-sources)). A public API for a different transport is not evidence about this wired route.
  - **Mac shortcut:** iPhone apps running on Apple-silicon Macs cannot connect to accessories through this framework ([A1, A4](SOURCES.md#official-apple-sources)).
- **Installing a development build.** Running an Xcode-built app on the phone requires Developer Mode ([A7](SOURCES.md#official-apple-sources)). An `external-accessory` background mode exists, but a foreground-only probe does not need it.
- **Locked-phone accessory setting.** iOS has a user setting under Settings > Face ID & Passcode > Accessories that controls accessory access while the phone is locked ([A9](SOURCES.md#official-apple-sources)). The probe procedure records that setting and keeps the phone unlocked.

### DJI facts (DOC)

- **iOS SDK status.** The latest iOS SDK identified in the reviewed sources is 4.16.2 (commit dated 2022-10-26). No official iOS V5 distribution was identified in the reviewed sources, including the `dji-sdk` organization's repository listing on 2026-11-03 ([D3, D6, D11](SOURCES.md#official-dji-sources)). Android MSDK 5.18.0 lists Mini 4 Pro, and its release notes pair Mini 4 Pro with RC-N2 and RC-N3 ([D1, D5](SOURCES.md#official-dji-sources)). No reviewed source lists Mini 4 Pro support in the iOS 4.x SDK.
- **Published protocol names.**
  - The 4.16.2 sample apps declare `com.dji.video`, `com.dji.protocol`, `com.dji.common` and `com.dji.logiclink`.
  - DJI's deprecated Bridge App declares the first three, plus the `external-accessory` background mode. Its own source uses DJI SDK bridge APIs rather than External Accessory directly.
  - The sample and Bridge App source is MIT-licensed; the SDK itself is under DJI's EULA ([D7, D8](SOURCES.md#official-dji-sources)).
  - These lists describe DJI's apps for older products. They are not evidence about RC-N3.
- **App Store route.** DJI's deployment page (dated 2018-09-03) describes App Store release of an app that uses a DJI MFi accessory: the developer applies to DJI, DJI forwards the application to Apple, and Apple issues a PPID that goes into App Review notes. In 2018 DJI described this as open to its Pro-tier developer accounts. The page says nothing about development builds ([D9](SOURCES.md#official-dji-sources)).
- **RC-N3 manual.** The RC-N3 user manual (v1.0, 2024.09) says:
  - connect the phone with the cable that matches its port, USB-C by default;
  - use DJI Fly;
  - link the controller and aircraft through DJI Fly;
  - update firmware through DJI Fly or DJI Assistant 2.

  For Android it advises choosing "charge only" at a USB prompt; it has no iOS-specific connection note ([D10](SOURCES.md#official-dji-sources)).
- **DJI's EULA** (last modified 2017-12-12):
  - §3.1 limits SDK use to developing, testing and operating applications for DJI products.
  - §3.2 restricts modifying, porting and reverse engineering the SDK (except where law prohibits that restriction). It also bars releasing SDK performance or functional evaluation results without DJI's prior written approval.
  - §3.3 limits redistribution.

  A probe that contains no SDK does not use these SDK terms, but whether DJI asserts other restrictions on observations of its accessory protocols is **UNKNOWN** ([D4](SOURCES.md#official-dji-sources)).

### Community reports (leads only)

- **C2 (README at `000c332`, pushed 2026-10-27).** Reports native iPhone External Accessory communication with a cabled RC-N3 and a DJI Neo, using a build installed on the author's own hardware rather than an App Store build. It names `com.dji.logiclink` as the channel and declares five DJI names, including `com.dji.fly`, which DJI's samples do not contain. It describes a required DJI Fly priming sequence. A contributed compatibility row reports RC-N3 + Mini 5 Pro with "no response". It makes no Mini 4 Pro claim. Its radio-power changes are outside this project, and its noncommercial code is not imported. **REPORT** [C2](SOURCES.md#community-research-leads)
- **C3.** An issue proposing to remove the Fly step by initializing the link directly has been open since 2026-09-06, with no comments as of 2026-11-03. Independent cold initialization is unsolved there. **REPORT** [C3](SOURCES.md#community-research-leads)
- **C4** documents mobile USB observations for other devices and has no license. Reference only. **REPORT** [C4](SOURCES.md#community-research-leads)

## 2. Public API, protocol and manufacturer prerequisites

| Prerequisite | Basis | Status on 2026-11-03 |
|---|---|---|
| RC-N3 advertises a protocol that the app declares | A4, A5 | **UNKNOWN** for this iPhone/iOS build; the H1 probe records the advertised names |
| Provenance of the protocol names to declare | D7 (DJI's MIT-licensed samples) for four names; `com.dji.fly` appears only in C2 | Four names documented by DJI. `com.dji.fly` is undocumented by DJI, so including it is an owner decision. |
| Manufacturer permission for third-party communication | A1 | **NOT OBTAINED**; DJI has not been contacted |
| Payload or message specification | A4 (the manufacturer must share it) | **NOT IDENTIFIED** in the DJI sources reviewed. Community notes are unlicensed. Controller and aircraft meaning is **BLOCKED**. |
| App Store distribution | D9 | Not needed for an owner-installed probe; required before any distribution |
| Development signing and device trust | A7 | Developer Mode plus an owner signing team. Team type is **UNKNOWN**. |
| Special entitlement | A1, A4, A5 | None is mentioned in the reviewed External Accessory pages. That absence is not a guarantee. |
| iOS build, Xcode and macOS versions | — | **UNKNOWN** (owner inventory) |

## 3. Signing and entitlement requirements

The probe is a development-signed app that the maintainer builds, signs and installs locally. The phone needs Developer Mode ([A7](SOURCES.md#official-apple-sources)). The app needs the `UISupportedExternalAccessoryProtocols` key with the reviewed names and no background mode. No DriverKit entitlement applies to iPhone ([A2](SOURCES.md#official-apple-sources)).

Two questions have no documented answer:
- Does iOS restrict External Accessory sessions for a development-signed app that has no MFi PPID? Apple and DJI describe only App Store distribution (A1, D9). C2 reports a working development build with a different aircraft.
- Does an Apple Developer Program team behave differently from free personal provisioning? This was not researched to a primary source; the owner records which one is used.

## 4. Controller detection is not an aircraft session

| Layer | What a probe without application-level writes can record | What it does not establish |
|---|---|---|
| L0 Cable and OS connection | Nothing until the system makes the accessory ready (A6). The owner may record any iOS prompt or settings entry as an inventory note. | App visibility |
| L1 Accessory visible | `connectedAccessories` entry or connect notification; name, manufacturer, model, firmware and hardware revision. **Never the serial number.** | Protocol readiness |
| L2 Protocols advertised | Non-empty `protocolStrings` (names only), which implies authentication (A4) | Permission or data flow |
| L3 Session created | A non-`nil` `EASession` for exactly one declared protocol. Creating a session is itself an OS and accessory operation with unknown effects on the target, and it may close another app's session (A6). | Any data |
| L4 Stream state | Input-stream state (open-completed, error, end) is recorded separately from output-stream state, which stays not requested. One stream opening never marks both open. | Any data |
| L5 Bytes read | Successful nonzero reads only: byte counts and times. A bytes-available event alone, or a zero-byte or error read, sets no first-input time. Payload is discarded without parsing. | Controller meaning, aircraft origin, readiness or freshness |
| L6 Controller or aircraft meaning | Requires a message specification | **BLOCKED** (no permitted source) |
| L7 Independently initialized aircraft session | Requires L6 in cold runs | **BLOCKED**; the [Aircraft-session GO](FEASIBILITY.md#first-hardware-experiment-transport-before-features) gate stays open |

**HYPOTHESIS:** RC-N3 may advertise its protocols and accept a session in a cold start, yet send no aircraft traffic until a DJI Fly–style initialization, consistent with C2/C3. The H1 cohorts below can falsify the transport half of this. They cannot test the aircraft half without L6.

## 5. GO / BLOCKED / NO-GO criteria

### Proposing the probe at owner checkpoint A

**GO-for-a-proposed-probe** requires every item below:
1. The [owner checklist](#owner-checklist) is complete.
2. The owner records a decision on the [rights questions](#unresolved-rights-and-publication-questions) for a non-distributed development build.
3. The probe declares only reviewed names and opens exactly one protocol per run. It makes no application-level writes: it never requests an output stream or sends bytes, and it neither parses nor retains payload.
4. The probe is bounded to 60 seconds per run and contains no SDK, vendor binaries or community code.
5. DJI Fly can be fully terminated before each run.
6. The M4 observation contract has been reviewed, so H1 records cannot conflate the L1–L5 layers.

**BLOCKED** while any of the above is unresolved. Also BLOCKED if a step would require application-level writes, handshake semantics, an unavailable entitlement or an undocumented permission.

**NO-GO for the External Accessory route on this combination** requires permitted evidence that a correctly built development probe cannot see RC-N3 at L2 in any run of either cohort while DJI Fly works on the same setup, or an explicit Apple or DJI prohibition. Inferring NO-GO from public sources alone is not justified.

### Stage gates after H1

These keep [FEASIBILITY.md](FEASIBILITY.md#first-hardware-experiment-transport-before-features)'s definitions:
- **Transport GO candidate:** L1–L5 with a clean close reproduced in the cold cohort.
- **Primed-only L5:** transport may exist, but independent initialization stays blocked.
- **Aircraft-session GO:** requires L6–L7 and stays **BLOCKED** pending permitted protocol meaning.

### Route status on 2026-11-03

| Route | Status | What would change it |
|---|---|---|
| External Accessory probe without application-level writes | **BLOCKED** on owner prerequisites | The owner checklist and rights decisions |
| Aircraft session over External Accessory | **BLOCKED**: no permitted protocol meaning | A DJI specification or permission, or a separately reviewed rights decision |
| Raw USB or DriverKit for this wired observation on the iPhone target | **NO-GO** under the cited constraints (A2, A3) | New Apple documentation covering iPhone |
| AccessorySetupKit for this wired observation | **Not applicable**: A8 documents Bluetooth and Wi-Fi accessory discovery | A different transport would be a separate route with its own evidence |
| Official iOS SDK for this combination | **BLOCKED**: 4.16.2 is the latest identified, and no official iOS V5 distribution was identified in the sources reviewed on 2026-11-03 (D3, D6, D11) | A DJI release or new DJI documentation |
| Android binary rehosting | **DEFER** to LAB-012 | A rights decision and its own spike |

## 6. H1 plan: no application-level writes, bounded, five cold and five primed runs

This plans the owner experiment in [HARDWARE_TESTING.md](HARDWARE_TESTING.md#initial-test-matrix); it is not a run request. It fits handoff schema v1 limits (10 repetitions, 60 seconds each). The committed experiment file belongs with the M5 probe source. "No application-level writes" describes the probe app; it is not a claim of zero OS or accessory traffic (see the definition under [Answer in brief](#answer-in-brief)).

**Bench conditions (all runs):**
- Propellers removed. Aircraft on a bench with the operator present and sticks untouched.
- No flight, camera or gimbal actions.
- Batteries at least 50% at the start.
- Phone unlocked throughout. The accessory setting is recorded, not changed.
- The RC-N3 cable stays connected to the iPhone for all ten runs.
- The probe app is force-quit between runs.
- The probe artifact SHA-256, iOS build, DJI Fly version and both firmware versions are recorded once and must not change mid-cohort.

**Window:** starts when the operator taps Start in the probe (t = 0 on the probe's monotonic clock) and ends at 60 seconds or at the first stop condition. The probe then closes the input stream and releases the session.

**Protocol:** exactly one protocol per run, the same for all ten runs, chosen by the owner at checkpoint A from the reviewed names. The proposal is `com.dji.logiclink`: DJI documents the name (D7) and C2 reports it as the channel. If it is not advertised, the run records L2 and opens nothing.

### Cold cohort (runs C1–C5), before any primed run

1. Confirm DJI Fly is not running and has not been launched since the last power-off.
2. Power off the aircraft and the RC-N3. Wait 10 seconds, then power both on in the owner's usual order, recorded and kept the same for every run.
3. Wait 30 seconds for the controller and aircraft link. Record any beeps or LED states, and any iOS prompt (do not accept it).
4. Launch the probe fresh and tap Start. Record L1–L5 for up to 60 seconds, then the clean close.
5. If DJI Fly launches or is opened at any point, mark the run **INCOMPLETE (primed)**. It does not count as a cold run.

### Primed cohort (runs P1–P5), recorded separately

1. Power-cycle as in the cold cohort.
2. Launch DJI Fly, wait until it shows the aircraft connected in camera view, then terminate Fly from the app switcher.
3. Wait 10 seconds after Fly terminates, then follow steps 4–5 of the cold cohort.
4. Record the exact Fly version, the priming duration and the termination-to-start delay.

### Per-run record

Use the [hardware-run template](templates/HARDWARE_RUN.md). Record only the following:
- Run ID and cohort.
- For each layer L1–L5: reached or not, with the time in milliseconds from t = 0.
- Advertised protocol names, the chosen protocol and the session result.
- Input-stream and output-stream states, recorded independently (output stays not requested).
- Time of the first successful nonzero read, total bytes read, and bytes per one-second bucket (at most 60 buckets).
- Stream errors, end events, and close and detach times.
- Any prompts and any controller or aircraft state change.
- The abort reason, if any.

Never record payload, serial numbers, account identities or location.

### Stop conditions

Stop the run, and the cohort if repeated, on any of:
- motor or propeller activity, or a controller or aircraft mode change;
- an unexplained beep or LED pattern, or any sign of RTH or flight-state change;
- a probe crash, or any prompt requesting pairing or permission beyond this plan;
- any output-stream request or application-level write attempt;
- a thermal or low-battery warning;
- a window over 60 seconds;
- Fly auto-launching in a cold run.

Invalid runs stay in the record. They are replaced only with the owner's decision, within the 10-run cap.

### Interpreting the results

| Cold cohort | Primed cohort | Meaning |
|---|---|---|
| L5 in all runs | L5 | Transport GO candidate. Aircraft session remains BLOCKED (no L6). |
| L3–L4 only (no bytes) | L5 | Fly priming changes traffic. Independent initialization is blocked; consistent with C2/C3. |
| L2 present, L3 `nil` | L2 present, L3 `nil` | Permission enforcement or protocol mismatch: BLOCKED. Ask DJI (see vendor question 1). |
| No L2 in any run | No L2 in any run | NO-GO candidate for this route on this combination, after confirming the prerequisites |
| Mixed within a cohort | — | INCOMPLETE. Record it; investigate a timing or ordering cause before repeating. |

## Owner checklist

Collected once so it does not need to be asked again. Keep serial numbers, account details and signing material private.

1. iPhone 15 Pro Max iOS version and build (Settings > General > About).
2. Mac model, macOS and Xcode versions; signing team type (Developer Program individual or organization, or free personal team); the bundle identifier to use.
3. Developer Mode available on the phone ([A7](SOURCES.md#official-apple-sources)); the accessory-access setting value ([A9](SOURCES.md#official-apple-sources)).
4. Cable: the RC-N3's supplied USB-C cable, with no adapter or hub (manufacturer/part noted privately).
5. RC-N3 firmware, Mini 4 Pro firmware and DJI Fly version (from DJI Fly), and whether the RC-N3 and aircraft are already linked.
6. Optional H0 note, with no app involved: with DJI Fly closed and the RC-N3 powered on and cabled, whether iOS shows any prompt or accessory entry. Absence is not conclusive.
7. A decision on including `com.dji.fly`, and the single protocol for H1 (proposed: `com.dji.logiclink`).
8. Rights and publication decisions on the questions below, and whether to send the vendor questions.
9. Bench safety: propellers removed, battery levels, and the operator's stop method (power off the aircraft, then the controller).

## Unresolved rights and publication questions

These are recorded for the owner. This project does not grant or claim legal clearance.

1. Whether DJI permits a third-party, development-signed, non-distributed app to open an External Accessory session with RC-N3 for read-only diagnostics (Apple: the manufacturer decides, A1).
2. Whether declaring DJI's published protocol names (D7) in such an app needs any DJI permission beyond their publication in MIT-licensed sample code.
3. Whether DJI's evaluation-disclosure clause or other terms reach observations from a probe that contains no SDK (D4). Until the owner decides, H1 results stay private apart from counts and timings the owner approves.
4. No message semantics may be derived from the DJI SDK (EULA §3.2), and none may be copied from C2 (noncommercial license) or C4 (no license). Any future traffic analysis needs its own rights decision.
5. An App Store PPID (D9) is outside this research and required before any distribution.

## Vendor questions (draft, not sent)

Under the #4 package these are drafts only; the owner decides whether and how to send them.

1. Does DJI permit development-signed iOS apps not distributed through the App Store to open External Accessory sessions with RC-N3 for read-only diagnostics?
2. Which accessory protocols does RC-N3 expose to third-party iOS apps, and is a message specification available under any program?
3. Does DJI plan iOS support for Mini 4 Pro with RC-N2 or RC-N3 in Mobile SDK V5?
4. May a project publish counts and timings observed by its own non-SDK app, and under what conditions?

## The question M4 answers

Can a probe's observations be recorded so that each of the following stays an independent fact, tied to a run and session identity under injected logical time?
- accessory visibility
- session creation
- input-stream state
- output-stream state, including not requested
- the first successful nonzero read
- close, disconnect and timeout

The reducer applying these observations must also meet four conditions:
1. No stream event or byte receipt sets aircraft readiness, initialization or telemetry validity. Those stay unknown unless a fixture supplies a separately defined synthetic observation.
2. Close and disconnect are terminal, and a late callback from an old run changes nothing.
3. An application-level write attempt is recorded as blocked.
4. A rejected event leaves prior state intact.

The M4 host-only harness tests that contract with original synthetic fixtures, using public API semantics only. It defines no DJI mechanism, contains no vendor identifiers or packet data, and performs no session or stream operation. The maintainer's [M2–M4 design guidance](https://github.com/bibek849/msdk-ios-lab/pull/16#issuecomment-6596777808) lists the synthetic cases.
