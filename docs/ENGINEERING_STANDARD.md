# Engineering standard

Adopted **2026-11-02** for MSDK iOS Lab. This is the project's implementation policy, informed by established platform practices; it is not a claim that one language is universally fastest. Apply it alongside [the roadmap](ROADMAP.md) and [feasibility gates](FEASIBILITY.md). No language choice supplies missing SDK rights, controller access or protocol knowledge.

## Language choices

| Layer | Default | Reason and boundary |
|---|---|---|
| iOS public API, lifecycle, session state, platform adapters and portable telemetry models | **Swift 6** | Keep Apple integration and the existing library in one language with explicit types, ownership and concurrency. Start packet parsing in Swift unless a concrete requirement justifies a native module. |
| A measured CPU hotspot, an approved reusable native library, or a deliberately shared native component | **C++20**, isolated behind a small interface | Adopt only for a documented performance or interoperability benefit. C++20 is the language baseline, not permission for an automatic rewrite or extra runtime. C++20 modules are not the Swift integration mechanism. |
| Boundary between Swift and a portable native component | **C-compatible API**, with C11-compatible headers | Prefer opaque handles, explicit sizes and caller/owner lifetime contracts. Keep C++ implementation details private. Direct Swift/C++ interoperability is an evaluated alternative with compiler/client compatibility tests. |
| Apple interoperability glue that needs it | **Objective-C / Objective-C++**, minimal scope | Use only when a required API or wrapper needs that boundary; keep protocol/business logic in the selected core language. |
| Official Android MSDK 5.18.0 reference host | **Kotlin/JVM** with DJI's supported integration path | Retain Java where a vendor sample/API requires it. Introduce NDK/JNI only for a justified shared native component, with versions pinned in the reference build. |
| Fixture generation, repository checks, handoff tools and offline analysis | **Python 3.10+** | Maintain the existing standard-library-first tooling. Python is outside the on-device transport, decoding and eventual command path. |

Rust may be proposed for a specific component when its ownership model, library ecosystem or measured result justifies another toolchain and FFI boundary. It is not a default dependency in the initial project. JavaScript/TypeScript, Dart, embedded interpreters and web UI frameworks are outside this library's high-rate transport/video/control implementation; separately reviewed future clients can choose their own presentation stack.

**Current baseline remains unchanged:** Swift tools 6.0, pinned Linux CI compiler 6.0.3, iOS 16/macOS 13 deployment declarations, and no third-party Swift dependencies. New APIs/language features must work with that baseline or arrive with an explicit compatibility decision and updated CI. A newer local Xcode is not permission to silently require Swift 6.2+ features. Deployment declarations do not prove device compatibility. Pins live in [provenance.json](../provenance.json).

## Architecture and interoperability

1. Keep portable contracts/parsers separate from Apple accessory, network and media adapters. Depend on small interfaces and supply original synthetic implementations for tests. MOCK, REPLAY and LIVE remain explicit.
2. Prefer the existing Swift module before adding another language. For a new language, framework, native dependency or cross-process boundary, record a short architecture decision: problem, alternatives, evidence, ownership/build cost, licenses, test targets and migration plan. The maintainer reviews that decision in the PR; routine work within the defaults needs no extra approval ceremony.
3. At a native boundary, document who allocates/releases each buffer or handle, how long borrowed memory lives, callback thread/queue, cancellation, errors and maximum lengths. Never let C++ exceptions unwind into Swift/C/JNI. Do not expose STL containers, native object layouts or allocator ownership across a C ABI. Treat raw pointers as scoped implementation details with checked bounds.
4. Batch related data where useful and minimize repeated language crossings and copies. Measure FFI overhead before moving an otherwise small operation. Keep Android JNI boundaries narrow; Android's [official guidance](SOURCES.md#official-engineering-references) identifies marshalling cost as a design concern.
5. Do not expose C++ interoperability through the public Swift product without checking downstream build flags and compatibility. Swift's interoperability documentation describes client/build constraints; C-compatible headers are the initial default, not a promise of an automatically stable ABI. Version any exported native contract explicitly.

## Platform and library defaults

| Concern | Project choice |
|---|---|
| Swift builds | Swift Package Manager for libraries/tests; Xcode for Apple application/signing/device work. Add CMake only if a separately built native component requires it. Do not introduce competing dependency managers for the same layer. |
| Controller connection | Public, permitted Apple accessory APIs through an adapter after S0 access gates. USB-C is not a raw-USB API; keep the direct-controller route separate from a network bridge. |
| Video | Prefer Apple's media stack: VideoToolbox when explicit low-latency codec/session control is needed, CoreMedia/CoreVideo for samples/buffers, and Metal only when GPU processing/rendering is justified. Use higher-level AVFoundation where it meets the requirement. Do not add a general software codec/transcode pipeline by default. |
| Hardware decode | Request the intended decoder mode, query the actual selected path where supported, and record fallback/failure. Apple exposes a query for whether hardware decode is in use; setting an enable flag alone is not evidence. Verify actual codec/profile/dimensions on the target phone. |
| Optional IP networking | Network.framework for native TCP/UDP/TLS transports; URLSession for HTTP resources. The portable core remains independent of these Apple APIs. A network client does not replace the direct accessory implementation. |
| Authentication/cryptography | Use established platform/protocol implementations with authenticated peers and explicit trust provisioning. Do not invent encryption or disable certificate validation to make a test pass. Low-level networking requires an explicit security configuration; selecting a framework alone does not authenticate a session. |
| Contracts | Preserve the existing JSON v1 diagnostic fixtures. Use typed, versioned structures, explicit units/clock basis and golden fixtures. Consider Protobuf for an actual cross-language/process protocol only when that boundary is approved; do not add serialization overhead to an in-process buffer path. Our diagnostics are not DJI wire packets. |
| Dependencies | Prefer maintained platform libraries and small audited dependencies. Record origin, license, exact version/commit, checksums for fetched artifacts and build options. Commit applicable resolution/lock files. Do not use floating versions or import vendor binaries into this MIT repository. |

These defaults select approaches for future implementations; they do not claim those integrations exist. See [primary engineering references](SOURCES.md#official-engineering-references).

## Runtime efficiency rules

- **Bound every stream.** Each queue declares its capacity, ownership, maximum acceptable age and overload policy. Preview frames can drop obsolete decoded frames when appropriate; compressed-stream drops must respect codec dependencies and a defined resynchronization path. Requests/events must not be silently lost or replayed like disposable preview frames.
- **Keep work separated.** File access, recording, networking, cloud checks, verbose logging and heavy decoding must not block the future command scheduler. Device callbacks enqueue bounded work and return promptly. Optional cloud/account/subscription request failures must not interrupt an established flight. Local control-link loss, stale input, RC takeover and session invalidation still follow the defined neutral/revoke behavior.
- **Define state ownership.** Use Swift structured concurrency and actor isolation for suitable lifecycle/control-plane state. Keep hot paths simple, bounded and explicitly scheduled. Do not create an unbounded task per frame or per packet, and do not suppress concurrency diagnostics to avoid explaining ownership. Actors, timers and native code do not provide hard real-time guarantees on iOS.
- **Budget allocation and copying.** Reuse buffers/pools when a measured path needs them; avoid repeated JSON, string formatting, array conversion or full-frame pixel copies in the hot path. Document all unavoidable copies and lifetime transfers. A pointer-based interface is not proof of zero-copy operation.
- **Parse defensively.** Check lengths, offsets, endianness, integer overflow, finite numeric values and enum/version validity before reading. No reinterpretation of untrusted bytes as unchecked native structs. Reject invalid/stale/out-of-session input without corrupting state.
- **Use observable failure modes.** Distinguish unavailable, stale, rejected, timed out, SDK acknowledged and physically observed results. Retry only explicitly idempotent operations; a reconnect or decoder restart must not restore command authority.
- **Keep diagnostics inexpensive.** Use structured, bounded logging and sampled timing instrumentation. Remove private identifiers and keep expensive formatting/storage outside rate-sensitive paths. Record diagnostic overhead when interpreting a benchmark.

## Performance acceptance

For a performance claim or a new rate-sensitive path, use [the performance report](templates/PERFORMANCE_REPORT.md). Define the workload and pass/fail budget **before** the comparison: input size/rate, desired queue age, memory cap, latency percentile/limit and overload behavior. The maintainer agrees the budget for that experiment. No global FPS or latency number is invented here while transport, firmware and source characteristics remain unqualified.

Measure optimized/Release builds with the same workload and relevant compiler settings. Record source/artifact identity, phone/OS/firmware, cold/warm state, thermal/power conditions, warm-up, duration, repeats, sample count and measurement endpoints. Report p50/p95/p99, observed maximum, deadline misses/jitter where relevant, throughput/drops, queue depth/age, CPU, memory growth, allocation/copy cost and energy/thermal observations. Mark unavailable metrics explicitly. An observed maximum is not a worst-case guarantee.

Use Instruments/Time Profiler/Allocations and appropriate OS timing tools for Apple-device profiling; use Android profiling tools for the reference host. Hosted CI supplies reproducible correctness and optional synthetic regression measurements, not physical performance acceptance. Small/noisy samples must not be advertised as a meaningful improvement.

For video, separate ingress, decode and presentation timing. Advancing frame identity, actual source cadence and optical end-to-end latency are distinct measurements. Configured resolution/FPS, decoder callbacks or an attractive preview cannot establish delivered camera quality or command latency. Accept an optimization only when correctness/recovery remain intact and the agreed benefit outweighs complexity and energy/memory costs.

## Required review evidence

- State the component's language/layer and any departure from these defaults.
- Include changed-layer correctness tests. Untrusted byte parsers need malformed, fragmented, truncated and boundary cases plus fuzzing. Unsafe/native FFI paths need ownership/lifetime, error propagation and concurrency checks plus applicable sanitizers. Use supported targets and mark unavailable runs NOT RUN before making readiness claims.
- Use golden cross-language fixtures when introducing a second implementation. Keep wire/API versions and clients in sync.
- Include a before/after performance report when claiming speed, latency, memory or energy improvement. A rewrite without measurements is an architectural proposal, not an optimization result.
- Pin new tools/dependencies and document portability, license and maintenance costs. Keep release and hardware claims scoped to their actual evidence.

The [PR template](../.github/pull_request_template.md) and [agent task brief](templates/AGENT_TASK.md) make these questions part of normal contribution review. This policy is human-reviewed; CI does not automatically prove every engineering requirement.
