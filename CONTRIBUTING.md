# Contributing

Start with the [README](README.md), [feasibility assessment](docs/FEASIBILITY.md) and the relevant [roadmap gate](docs/ROADMAP.md). The current implementation is a software-only foundation. Native DJI access and all physical capabilities are unvalidated in this repository.

## Work in small, reviewable steps

Fork this repository and create a topic branch. Pick a [backlog ID](docs/CONTRIBUTOR_BACKLOG.md), explain one question, and submit one coherent change. Use an issue for coordination before substantial overlapping work; a discussion does not grant access to the owner's hardware. No contributor needs credentials, aircraft serials or private flight logs to work on synthetic tests.

```sh
swift test
swift run msdk-ios-replay
python3 tools/check_repository.py
```

Include commands and actual results in the PR. Record changed-layer validation in `docs/TEST_RESULTS.md`; never re-label synthetic or host-only tests as iOS or hardware checks. The maintainer merges after review; no automatic hardware deployment or automatic stage promotion is configured.

## Handoff for a physical test

Supply a source commit, reproducible build instructions, dependency versions, a narrowly scoped procedure, pass/fail criteria, stop conditions and expected evidence. If submitting an artifact, include its SHA-256 and build provenance. The maintainer reviews and normally rebuilds/signs locally before installation. Do not put certificates, signing profiles or app keys in Git or issue attachments.

Use [the hardware-run template](docs/templates/HARDWARE_RUN.md) and [the hardware guide](docs/HARDWARE_TESTING.md). Maintainers control when a test happens. An unrun test is `NOT RUN`, not a failed implementation. A blocked entitlement or permission is `BLOCKED`, not evidence that every native route is impossible.

## Original code and source provenance

Contribute only material you are entitled to provide under this project's MIT license. By submitting a contribution, you confirm that you have that right and agree to license it under MIT. Preserve attribution and license notices for any approved third-party material. This statement is not permission to relicense DJI SDKs or differently licensed community code.

- Do not import proprietary SDK binaries/source, extracted DJI Fly frameworks, keys, model weights or private media.
- Document the source and permission basis before adding a protocol implementation or copied code. An observed behavior is not itself a license to copy its implementation.
- Do not assume that public sample code, undocumented protocols or the availability of a repository settle implementation or redistribution rights.
- Resolve the applicable DJI terms and publication restrictions before sharing SDK-derived performance or functional reports. Original synthetic tests can be shared with explicit provenance.
- Do not include radio-region modification, geofence bypass, firmware modification or authentication bypass in this project's work.

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and [the source register](docs/SOURCES.md).

## Engineering boundaries

Unknown readings stay unknown. Include units, session identity, sequence and freshness. Keep replay delivery separate from recorded source. Native and Android-backed adapters must identify themselves. Receiving bytes, parsing a message, accepting a request and observing aircraft behavior are different events.

Future control work requires one authority owner, bounded and expiring intents, conflict/replay/staleness rejection, physical RC takeover and explicit rearm. Pairing and reconnection never grant authority. Telemetry, video, storage and network services must not block a future command loop. This repository currently has no executable flight path.
