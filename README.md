# MSDK iOS Lab

**An open-source experiment toward native iPhone support for a small, useful subset of DJI MSDK 5.18.0 capabilities.**

We want to learn whether an iPhone can establish its own controller/aircraft session, receive telemetry and video, and eventually request bounded control without an Android device doing the DJI work. We will build and test this one stage at a time, with remote contributors writing small, reviewable changes and a local maintainer testing exact builds on owned hardware.

**Status: research foundation; no native DJI connection or flight control implemented.** This is an independent project, not an official DJI SDK, a complete MSDK port, or a flight-ready application. No official iOS V5 distribution was identified in the [official sources checked](docs/SOURCES.md). The open Android sample and the proprietary SDK have different licenses.

## Start here

- [INSPIRATION.md](INSPIRATION.md): why this is worth trying, the hypotheses, and what useful failure looks like.
- [Feasibility](docs/FEASIBILITY.md): platform constraints and independently checked community leads.
- [Roadmap](docs/ROADMAP.md): incremental stages, acceptance evidence and stop conditions.
- [Contributor backlog](docs/CONTRIBUTOR_BACKLOG.md): scoped tasks for remote developers.
- [Hardware testing](docs/HARDWARE_TESTING.md): contributor-to-maintainer handoff and test procedure.
- [Compatibility](docs/COMPATIBILITY.md): combinations and capabilities, with unknowns retained.
- [Test results](docs/TEST_RESULTS.md): commands actually run; hardware work remains separate.

## The first decisive experiment

Target **iPhone 15 Pro Max → RC-N3 → Mini 4 Pro**, with the iOS build and firmware versions still to be recorded. Can an original, signed, read-only iPhone probe use a permitted accessory channel and establish a session from a cold start **without DJI Fly priming it**?

Opening an accessory, recognizing a controller, receiving aircraft telemetry, decoding video and commanding the aircraft are separate milestones. A success on Neo or an M-series iPad does not qualify this combination. We will keep both successes and failed hypotheses, without inventing a completion date for unresolved platform access.

## Research routes

| Route | Purpose | Current status |
|---|---|---|
| Small native Swift implementation | Primary route: independently implement the capabilities needed for one combination, using permitted interfaces and authorized protocol knowledge | Access, session initialization and behavior unproven |
| DJI-supported source/core port | Prefer vendor cooperation if portable source or an iOS core becomes available under suitable terms | No such access established |
| Android binary compatibility experiment | Optional, separately gated research into runtime/JNI/loader dependencies | No DJI-on-iPhone evidence; permission review required first |
| Android 5.18.0 reference bench | Compare behavior against the official SDK on supported hardware | New project baseline not yet run |
| Android-backed network client | Optional way to exercise Swift contracts and networking | A bridge would remain an Android dependency and would not close the native-port goal |

The current Swift package contains only original telemetry contracts, validation and synthetic replay. There is no accessory transport, networking, video decoder, registration implementation, motor command or extracted vendor code.

## Try the software foundation

Install Swift 6.0 or later, then run from the repository root:

```sh
swift test
swift run msdk-ios-replay
python3 tools/check_repository.py
```

See [the Swift core guide](docs/SWIFT_CORE.md) for the fixture format, validation semantics and limitations. Replay is labeled independently from the original sample source. Local/macOS or Linux success does not prove an iOS device build, accessory access or DJI behavior.

## How contributions become hardware evidence

1. Choose one [backlog task](docs/CONTRIBUTOR_BACKLOG.md) and state the question it answers.
2. Submit a PR with the exact commit, reproducible tests, provenance and one bounded experiment.
3. A maintainer reviews the change, builds/signs locally where needed, and records the artifact hash.
4. The hardware owner follows the agreed procedure and records pass, fail, blocked or not run.
5. Advance only the capability and combination actually demonstrated. Resolve publication rights and redact private information before sharing hardware reports.

Contributors do not need a drone for the initial contract, replay, documentation and parser work. They do not receive unattended control of the owner's aircraft.

## Scope and independence

This repository has its own Git history, MIT-licensed original code, roadmap and evidence. It does not depend on or contain Skywarden source, credentials, private flight data or media. Future consumers can evaluate its results through a separately reviewed integration. Creating this project does not resume Skywarden UI implementation.

[CONTRIBUTING.md](CONTRIBUTING.md) explains the workflow. [Third-party boundaries](THIRD_PARTY_NOTICES.md) distinguish our MIT license from vendor SDK terms and community source licenses. DJI, MSDK and product names identify compatibility targets; they do not imply endorsement.
