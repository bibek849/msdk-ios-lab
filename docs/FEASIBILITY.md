# Native iOS feasibility

Research checkpoint: **2026-11-02**; native-access dossier **2026-11-03**. Target: **MSDK 5.18.0 capabilities on an iPhone 15 Pro Max**, initially with the owner's Mini 4 Pro and RC-N3. The phone's exact iOS version, provisioning, cable and controller/aircraft firmware still need recording. No project hardware test has run.

The central experiment is native iPhone interoperability. We will test whether a useful subset can be implemented through a permitted direct connection, and whether any narrowly scoped native-library compatibility work is viable. We will not call a Swift package, replay demonstration or Android relay a completed iOS port.

## What is established

DJI publishes Android V5.18.0 and an open sample that depends on separate SDK artifacts. Its checked official iOS repository identifies V4.16.2; no official iOS V5 distribution was found in the sources reviewed. This establishes a platform gap, not a native implementation. [D1–D3](SOURCES.md#official-dji-sources)

The SDK and sample have different terms. DJI's SDK EULA restricts porting and reverse engineering subject to its stated exceptions, and also addresses disclosure of SDK evaluation results. Stage 0 must establish applicable permissions and publication rights; original project code can proceed independently. Do not import vendor binaries or present a clean-room process as automatic legal clearance. [D2, D4](SOURCES.md#official-dji-sources)

Apple's public External Accessory model is manufacturer-supported accessory communication, not arbitrary USB endpoints. General iPhone raw USB access is not established by USB-C. USBDriverKit is a separate Mac/M-series-iPad option, and success there would not close the iPhone gate. [A1–A3](SOURCES.md#official-apple-sources)

The [native access dossier](NATIVE_ACCESS_DOSSIER.md) (2026-11-03) adds three findings:
- **Apple:** only one session can exist per accessory and protocol; the protocol list is empty until the accessory authenticates; and the manufacturer controls third-party app access ([A1, A4–A6](SOURCES.md#official-apple-sources)).
- **DJI protocol names:** DJI's 4.16.2 iOS samples publish protocol names but no message specification ([D7](SOURCES.md#official-dji-sources)).
- **App Store route:** DJI's MFi route for App Store release says nothing about development builds ([D9](SOURCES.md#official-dji-sources)).

The dossier finds no public NO-GO for the proposed wired External Accessory observation. A probe without application-level writes is **BLOCKED** on the owner's inventory and rights decisions; it makes no claim of zero OS or accessory traffic. Manufacturer access and target validation remain open, and aircraft-session meaning stays **BLOCKED**. [ADR 0002](decisions/0002-native-transport-component.md) records the component decision and the minimum M4/M5 plan.

## Why native experiments remain worthwhile

Community projects provide specific leads we can test without treating their conclusions as ours:

| Lead | Relevant reported result | Boundary |
|---|---|---|
| [Neo Control](SOURCES.md#community-research-leads) | Original Swift app for first-generation Neo over BLE/Wi-Fi | Its author reports no telemetry/video. This is a different aircraft and transport from Mini 4 Pro + RC-N3. |
| [DJI-FCC-Unlock-iOS](SOURCES.md#community-research-leads) | Author reports native iPhone External Accessory communication with RC-N3 + Neo | The project has a noncommercial license; we do not import it. Its radio/altitude modifications are outside this project's scope. |
| [That project's issue #4](https://github.com/andreapianidev/DJI-FCC-Unlock-iOS/issues/4) | A controller session can exist while aircraft communication still depends on a preceding DJI Fly session | Cold and warm start are separate test cases. Controller detection is not aircraft readiness. |
| [dji_protocol](SOURCES.md#community-research-leads) | Author documents mobile USB observations for Goggles N3 and first-generation Mavic Pro controller | No Mini 4 Pro/RC-N3 proof; no repository license file found at the reviewed revision. Cite the lead without copying code or packet tables. |
| [Klepton](SOURCES.md#community-research-leads) | Android ARM64 library relinking with compatibility services on macOS/visionOS | Its described focus is Java-thin applications without ART/JVM. No DJI, iPhone transport or MSDK initialization result was found. |

These leads justify experiments about connection and runtime dependencies. They do not establish safe flight, supported MSDK APIs, a redistributable SDK, or App Store eligibility.

## Three routes to investigate

### 1. Original native implementation of a narrow capability subset

Apply the [reuse-first policy](PORTING_POLICY.md) before writing an implementation. Preserve any compatible, permitted component and isolate platform differences behind adapters. Original implementation is for necessary gaps; it is not an instruction to translate all SDK logic. A source/core reuse route remains conditional on obtaining suitable access and rights.

Start with connection lifecycle, read-only observations and video framing. Use original Swift interfaces with explicit capability states, missing values, timestamps and provenance. Keep packet parsing detached from the physical transport so synthetic fixtures can exercise fragmentation, malformed lengths, timeout and reconnection without a drone.

**First unknown:** can this app open and sustain a permitted External Accessory session on the actual iPhone/controller combination? **Next unknown:** can that connection reach the aircraft after a true cold start? Data receipt, meaningful telemetry and decodable video each need their own evidence.

### 2. Narrow native-library compatibility experiments

Before touching DJI artifacts, use an original toy Android ARM64 library to test a small ELF-to-Apple compatibility hypothesis. Account for object format, imports, JNI assumptions, threads, callbacks, signing and device execution. An ARM64 CPU match is insufficient.

For any subsequently authorized MSDK experiment, inventory the pinned artifact's native and managed dependencies, registration services, USB ownership, decoding and lifecycle requirements. Select one bounded initialization question. Stop that experiment if its dependency closure is too broad or unavailable; retain the independent Swift contract and findings. Neither toy-library success nor successful dynamic loading proves MSDK functionality.

### 3. Android reference and optional bridge

The official Android SDK is a reference for capability semantics and owner-run comparisons. A separately labeled bridge may help develop the Swift API and video client. It is an optional fallback or test aid; it does not satisfy native iPhone acceptance. Keep this project independent from Skywarden's source and release claims.

## First hardware experiment: transport before features

1. Record the iPhone 15 Pro Max's iOS build, Xcode/signing setup, cable, RC-N3 and Mini 4 Pro firmware, and build commit/hash. Record the permission basis and what evidence may be published.
2. Build a minimal public-API accessory probe. Use only protocol declarations whose provenance and permitted use have been reviewed. Observe attachment, advertised supported protocols, session creation, stream status and disconnection. No regulatory changes or flight commands.
3. Test **cold start** with the controller and aircraft power-cycled and no preceding DJI Fly session. Bound the observation window and report timeouts, including successful controller detection with no aircraft data.
4. Separately test a **warm reference condition** after ordinary DJI Fly viewing, if approved for the test plan. Do not describe this as independent initialization. Keep results distinct and retain failed attempts.
5. Run five independent cold-start cycles and five separately recorded primed comparison cycles, with a maximum 60-second observation window each, as specified in [the hardware guide](HARDWARE_TESTING.md). Stop for unexpected motor activity, altered aircraft state, unstable power or a test step outside the reviewed scope. Ground testing uses removed propellers and the owner's direct supervision.

**Transport GO:** reproducible session creation and receipt on the named hardware with an understood permitted route. **Aircraft-session GO:** independently demonstrated cold-start communication. Neither gate grants command authority. If only warm sessions work, record that dependency and make cold-start initialization the next research issue. If the required route is unavailable, mark this route blocked while original offline work continues.

## Evidence that can advance later stages

Record request, runtime acceptance, SDK acknowledgment and observed aircraft result separately. Every result names its combination and provenance: MOCK, REPLAY or LIVE. A video frame is not evidence of telemetry accuracy or control availability. Keep unknown readings unknown. Commands remain disabled until a separately reviewed authority implementation and hardware test plan exist; reconnect never restores authority automatically.

We can finish a stage with a useful negative result. The deliverable is the smallest reproducible answer to that stage's question, with limitations that a remote contributor can act on.
