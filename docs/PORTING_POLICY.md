# Reuse first; port only what iOS needs

Adopted **2026-11-02**. Our objective is a useful, tested native iOS capability subset, not a translation of every MSDK 5.18.0 class or subsystem. Preserve compatible, authorized implementations. Change only the smallest part needed to satisfy the current iOS experiment.

This policy comes **before** the language defaults in [ENGINEERING_STANDARD.md](ENGINEERING_STANDARD.md). Swift 6 is the default for necessary new iOS code; it is not a reason to rewrite working, legally reusable code in another language. A supported reusable C or C++ component can keep its implementation language. Retaining a different language/runtime still requires evidence that its iOS build, deployment, maintenance and dependency costs are acceptable.

## Decide in this order

1. **Need:** name the capability, target combination and current [roadmap gate](ROADMAP.md). Does the experiment actually require this component? If not, defer it. A counterpart in the Android SDK is not itself a requirement.
2. **Availability and rights:** identify the exact source or artifact, version, license/permission basis and allowed uses. Distinguish source access, permission to modify, device execution, redistribution and publication of results. Unknown or restricted rights cannot be resolved by choosing a new language. Use original independent work where appropriate; do not treat the sample's license as permission to port SDK internals.
3. **Compatibility evidence:** check supported iOS targets, public platform APIs, runtime dependencies, signing/deployment constraints and the component's actual behavior. Keep source portability, binary compatibility and hardware behavior separate. Unknown compatibility calls for investigation, not a rewrite.
4. **Smallest intervention:** try the applicable reuse or adaptation option below. A port proposal identifies the specific incompatible dependency or behavior, why a smaller boundary change cannot resolve it, and what compatible code remains unchanged.
5. **Verification:** test the changed boundary and relevant unchanged behavior. Record exact versions, commands and limitations. A simulator or host pass cannot close an iPhone/controller gate.

Use [the component decision template](templates/COMPONENT_DECISION.md) in an issue or PR. A small task needs a small decision record, not a whole-SDK audit. Update the decision when new evidence changes it.

## Allowed decisions

| Decision | Evidence needed | Expected change |
|---|---|---|
| **DEFER** | Component is not needed for the active capability/gate | No implementation work; name the later need if known. |
| **REUSE** | Authorized implementation/artifact supports the required iOS target and behavior | Integrate the existing implementation; pin its origin and preserve its license obligations. |
| **REBUILD** | Authorized source appears portable; only its build/packaging must target iOS | Compile that source for the actual Apple target. Keep implementation unchanged where possible; validate the resulting artifact. |
| **ADAPT** | The useful core is compatible, but a narrow platform boundary differs | Keep the core; add a small transport, lifecycle, threading, allocation, media or API adapter. Test both sides. |
| **PORT MINIMUM** | A necessary implementation has a demonstrated iOS incompatibility that cannot be resolved by the preceding options, and modification is permitted | Change only the incompatible part and required callers/tests. Keep behavior and public contracts stable where feasible. |
| **IMPLEMENT MISSING CAPABILITY** | No usable implementation is available, but the capability is needed and its permitted interface/behavior is sufficiently understood | Write a narrow original implementation. State explicitly that this is new code, not a translation of unavailable SDK source. |
| **INVESTIGATE / BLOCKED** | Need, rights, source availability, platform access or compatibility remains unresolved | Run a bounded permitted probe or record the missing prerequisite. Do not expand into speculative implementation. |

These are decisions, not a fixed pipeline that every component must traverse. A proposed reusable component remains unqualified until its required tests pass. A thin adapter may be the entire iOS change for that component.

## Source, binaries and behavior are different questions

An Android distribution is not an iOS distribution. An AAR, JVM dependency or Android native library cannot be treated as an installable iOS library merely because both devices have ARM64 processors. The [feasibility dossier](FEASIBILITY.md#2-narrow-native-library-compatibility-experiments) identifies object format, ABI, JNI/runtime, signing and platform-access questions. A binary incompatibility does **not** establish that every algorithm or authorized source file needs rewriting.

Likewise, an iOS compilation does not prove accessory access, session initialization, telemetry accuracy or safe command behavior. A reusable parser may need no implementation changes while the Android USB/lifecycle adapter needs replacement. That is an architectural example, not a finding about DJI's unpublished component boundaries.

For MSDK itself, this project has not established access to portable vendor source or an authorized iOS core. Do not promise that we can edit a piece “inside the SDK” before access and permission exist. Keep any authorized vendor dependency separate from this repository's MIT-licensed original work. The [third-party boundaries](../THIRD_PARTY_NOTICES.md) and [official source register](SOURCES.md) remain authoritative for the evidence collected here.

## Starting inventory

This is a planning inventory, not a claim to have inspected or qualified DJI SDK internals.

| Component or capability | Current evidence | Current decision / next proof |
|---|---|---|
| Original Swift telemetry contracts, validation and replay | Existing project source and synthetic tests; no DJI transport | **REUSE** within the software foundation. Keep its contracts; device behavior remains unqualified. |
| Permitted iPhone controller transport | iPhone 15 Pro Max target confirmed; exact OS build and an accessible route on the target combination remain unresolved | **INVESTIGATE / BLOCKED** at S0. Establish access before building a broad transport stack. |
| Native cold-start aircraft session and read-only observations | No project hardware result or usable vendor source established | **INVESTIGATE / BLOCKED**. Prove the smallest initialization path after access and rights gates; then choose reuse, adaptation or necessary original implementation. |
| Authorized portable vendor or third-party core | No specific approved core identified for the native path | **INVESTIGATE** only when a concrete candidate serves the active gate. Check rights, dependency closure and iOS build before proposing a rewrite. |
| Android MSDK 5.18.0 reference host | Official Android integration is the reference route; this project's hardware baseline is not run | Keep it on Android under the applicable terms. **DEFER** translation of its Android host UI/runtime. Its purpose is comparison. |
| iOS video decoding | Future S4 capability; no acquired stream or decoder integration exists | **DEFER** until needed. Evaluate native Apple media facilities before porting an Android decoder pipeline. A decoder choice does not solve stream acquisition. |
| Camera/gimbal actions, flight, missions and unrelated SDK features | Later gates or outside the initial subset | **DEFER**. Add only a named necessary capability after its preceding gates; no blanket API parity backlog. |

## Stage-by-stage contribution rule

- **S0:** produce the capability dependency sketch and a bounded compatibility/access question. It is enough to establish that a candidate is unavailable or a route is blocked. Do not reverse-engineer or port the whole SDK to populate an inventory.
- **S1:** reuse the original contracts and synthetic tools. Add a fixture, test or contract only for a named requirement, with MOCK/REPLAY/LIVE provenance intact.
- **S2:** use the official Android reference through its supported integration. Reference setup is not a mandate to translate Android host code.
- **S3:** implement only the necessary direct iOS connection and read-only path. Keep portable work outside the platform adapter. Cold start and telemetry are independently qualified on the exact hardware.
- **S4:** add acquisition, media adaptation and decoding only to the extent needed by the demonstrated stream. Reuse suitable platform facilities and measure the actual result.
- **S5–S6:** add a specific bounded action only after the existing authority, takeover and operator gates. Reuse does not inherit hardware approval from another implementation or device.

## Review and acceptance

A PR that adds or changes an implementation identifies its active capability, component decision, evidence of need and smallest affected boundary. A rewrite also shows the demonstrated incompatibility or measured requirement that the existing implementation cannot satisfy, alternatives considered, retained code and regression evidence. “More modern,” “AI can translate it,” and “language X is faster” are not sufficient reasons.

Performance claims follow [the engineering standard](ENGINEERING_STANDARD.md#performance-acceptance) and require measurements. Compatible existing code can still need a separately justified correctness, security or performance fix; keep that rationale explicit instead of calling it an iOS port.

The maintainer reviews decisions in normal PR review. Hardware-dependent acceptance uses the existing [exact-commit handoff](HANDOFF_FORMAT.md) and [owner-run procedure](HARDWARE_TESTING.md). No decision label, software test, successful build or AI report grants aircraft authority or establishes native compatibility by itself.
