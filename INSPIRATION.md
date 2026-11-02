# Why MSDK iOS Lab is worth experimenting with

We have a specific question, access to real hardware, and a way for people in different places to collaborate: **can we give an iPhone a small, useful subset of the capabilities available through Android MSDK 5.18.0, reusing compatible components and implementing only the necessary gaps?**

The ambition is native iPhone operation. An Android relay can be useful for comparison, but it cannot answer that question. We are starting with one combination—iPhone 15 Pro Max, RC-N3 and Mini 4 Pro—and a narrow sequence of measurable outcomes. We are not starting by translating thousands of SDK method names.

## Why try at all?

DJI's own iOS applications demonstrate that iPhone hardware can participate in modern DJI workflows. That does not give third-party developers access to DJI's internal implementation. The gap between those two facts is precisely the research problem.

The [shared discussion that inspired this project](https://chatgpt.com/share/6ae91470-a894-83e9-b9c8-56fd67b81f81) identified partial community precedents: an independent Swift client for the original Neo, reports of an iOS accessory channel on RC-N3, published transport observations, and an Android-native-library compatibility project for other Apple platforms. We checked the underlying projects in the [source register](docs/SOURCES.md). Each offers a lead, not proof that our target works. None establishes native MSDK 5.18.0 parity on our iPhone/aircraft combination.

A focused experiment can still create useful public work: an honest compatibility map, a reusable Swift data model, reproducible synthetic fixtures, tested stream parsers, clearly isolated platform adapters, and precise explanations of what remains inaccessible. A well-supported negative result can save the next contributor weeks of guessing.

## What makes this approach different from a wish list

We separate three problems that are easy to confuse:

1. **Access:** can our signed iPhone app open an authorized controller communication channel?
2. **Meaning:** can it independently establish a session and interpret useful aircraft data?
3. **Behavior:** can supported requests produce the intended physical result, with safe loss-of-authority behavior?

An accessory enumeration screenshot answers none of the later questions. A warm connection after DJI Fly ran is not a cold-start success. A command acknowledgment is not observed aircraft behavior. A synthetic test is not a flight test.

Our initial approach is a small native path with replaceable transport and protocol boundaries. The [reuse-first policy](docs/PORTING_POLICY.md) preserves compatible, permitted code: rebuild unchanged source or adapt a boundary before porting a specific incompatible part. Swift is a default for necessary new iOS code, not a requirement to rewrite existing implementations. A vendor-assisted port would be welcome if DJI supplies suitable access. Binary rehosting remains a separate research hypothesis: matching ARM64 CPUs does not supply Apple's executable format, Android services, JNI, SDK registration or controller access.

## How we will tackle it

**First, reduce uncertainty cheaply.** Record exact hardware and source versions. Establish what material may be used and published. Design a read-only accessory experiment using public Apple APIs. Request necessary vendor cooperation through an explicitly approved outreach task if needed; no credentials or copied SDK internals belong in this repository.

**Then, make remote work independently testable.** Contributors can improve the original Swift package, deterministic replay fixtures, malformed-input handling and experiment documents without a drone. Small changes should answer one question and include the next hardware observation that could disprove the hypothesis.

**Keep agents connected to the work.** A contributor can use their own AI subscription and GitHub account to follow a scoped issue, prepare a reviewed change, and receive our hardware feedback on the same issue/PR. The [event workflow](docs/AGENT_EVENT_WORKFLOW.md) supports human-triggered work and optional contributor-owned checks; no shared account or always-on central agent is required for the initial collaboration.

**Then, close the physical loop locally.** The maintainer reviews and builds a specific revision, installs a signed artifact on the owned phone, and runs a finite test. We record exact device and firmware versions, procedure, expected result, actual result and limits. Sensitive raw evidence and SDK-derived evaluation reports remain private until publication rights are resolved.

**Finally, expand by capability.** Cold-start session establishment comes before telemetry qualification; video is a separate milestone; camera and gimbal actions precede any flight experiment. Flight authority, physical RC takeover, stale input, reconnect and deliberate rearm require their own gates. No version label or green unit-test badge replaces these observations.

The [roadmap](docs/ROADMAP.md) defines the gates. We will revise the plan when evidence changes, retain failed experiments and resist adding more aircraft before one combination is understood.

## Useful outcomes, even if a full port is impossible

| Outcome | What we gain |
|---|---|
| Native controller access works, cold-start initialization is blocked | A precise boundary for the next protocol or vendor-cooperation task |
| Telemetry works, video does not | A limited read-only capability with honest scope |
| Direct access requires unavailable authorization | A documented stop condition; no false promise of a working native library |
| Only the Android reference/bridge works | Reusable Swift client work, explicitly labeled Android-backed |
| A narrow native subset works reliably | A foundation to qualify further capabilities one at a time |

## What success would mean

A signed app on the identified iPhone starts from a cold state, communicates with the identified controller and aircraft without another app or Android host doing the initialization, and passes the separately documented telemetry, video and eventual control gates. Other hardware remains unverified until tested.

We cannot promise that outcome today. We can promise a project structure in which every contribution makes the uncertainty smaller and every claimed capability has evidence behind it.
