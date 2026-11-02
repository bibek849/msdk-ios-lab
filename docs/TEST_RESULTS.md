# Test results

## Engineering standard — 2026-11-02

Scope: language/platform/performance policy, contributor instructions, review fields, primary references and a performance-report template. No runtime code, package manifest, compiler baseline, dependency or device configuration changed.

```sh
python3 tools/check_repository.py
git diff --check
```

**PASS:** 29 Markdown files, 86 local link targets and 3 JSON files; no whitespace errors. An independent policy review checked language/interoperability limits, Swift 6.0 compatibility, media queue rules and authority boundaries. The final wording explicitly distinguishes optional cloud failures from local control-link/stale-input revocation.

The required hosted workflow runs the existing software suites separately for the PR. No new local runtime tests were needed for this documentation-only change. Benchmarks, hardware performance, signed iPhone builds, DJI, Unity and headset checks are **NOT RUN**. The new report template records no measurements and establishes no speed improvement.

## AI contributor workflow — 2026-11-02

Scope: contributor documentation, metadata-only handoffs, repository review workflow and CI. No DJI source, aircraft transport, iOS UI or flight behavior changed.

From the repository root, using Apple Swift 6.4 and Python 3.14.6 on arm64 macOS:

```sh
make check
```

**PASS:** 16 Swift tests, 11 Python handoff tests, local Markdown/JSON checks and synthetic replay (three accepted samples). The command ran with normal development-cache access; no environment workaround was needed in this run. The Python-only verification was also run independently:

```sh
python3 -m unittest discover -s tools/tests -v
python3 tools/check_repository.py
git diff --check
```

**PASS:** the handoff suite covers exact commit/checksum identity, dirty tracked files, untracked specifications, overwrite refusal, excluded untracked/private files, no execution of supplied command strings, path/symlink boundaries, malformed/oversized specifications and draft hardware requests. Command-stage hardware requests are rejected. Metadata validity never establishes operator approval or safety.

Independent review found a macOS case-insensitivity problem with a proposed `tests/` directory beside Swift's `Tests/`. The final Python tests live under `tools/tests/`, and all commands use that exact path. No further blocking review findings remained.

The updated CI adds a separate handoff test/export job, keeps read-only permissions and hosted runners, and pins checkout v7.0.1 by commit. Its check runs record Linux results separately from this local evidence. Hardware, signed iPhone builds, DJI access, Unity and headset testing remain **NOT RUN** for this change.

## Initial foundation — 2026-11-02

Scope: original Swift contracts, synthetic fixtures and project documentation only. No DJI SDK artifact is included or executed. Prior results from other projects do not count here.

Environment: Apple Swift **6.4** (`swiftlang-6.4.0.34.1`, `clang-2100.3.34.1`), arm64 macOS. The minimum package tool version is 6.0; local success with 6.4 is not an exact-6.0 compiler result. CI is configured separately with the official Swift 6.0.3 Jammy image pinned by digest in [provenance.json](../provenance.json).

### Host unit tests

From the repository root:

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/msdk-ios-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/msdk-ios-swift-cache \
swift test --disable-sandbox \
  --scratch-path /private/tmp/msdk-ios-lab-build \
  --cache-path /private/tmp/msdk-ios-package-cache
```

**PASS: 16 XCTest tests, zero failures.** Covers wrong schema/session, duplicates/out-of-order input, stale receipt and monotonic clock errors, invalid numeric values, missing measurements, bounded input, synthetic-origin constraints and replay delivery identity. This tests contract behavior, not a DJI protocol parser or transport.

Ordinary `swift test` initially encountered this managed environment's home-cache and nested sandbox restrictions. The command above used temporary caches and disabled only SwiftPM's nested manifest sandbox. No system security setting was changed. Ordinary contributors can use the shorter README commands on an unrestricted development setup.

### Synthetic replay executable

```sh
CLANG_MODULE_CACHE_PATH=/private/tmp/msdk-ios-clang-cache \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/msdk-ios-swift-cache \
swift run --disable-sandbox \
  --scratch-path /private/tmp/msdk-ios-lab-build \
  --cache-path /private/tmp/msdk-ios-package-cache \
  msdk-ios-replay fixtures/synthetic-telemetry-v1.json
```

**PASS: exit 0, three synthetic samples accepted.** Output states `delivery=REPLAY recordedSource=MOCK`, `nativeIOSTransport=UNAVAILABLE` and `hardwareValidated=false`; absent values display `UNAVAILABLE`. No network, USB, video or aircraft command is used. Local queue age is validated; original sensor freshness remains unknown.

### iOS SDK and repository checks

```sh
xcodebuild -version
xcrun --sdk iphoneos --show-sdk-version
xcrun swiftc -typecheck -parse-as-library -module-name MSDKIOSCore \
  -target arm64-apple-ios16.0 \
  -sdk "$(xcrun --sdk iphoneos --show-sdk-path)" \
  -module-cache-path /private/tmp/msdk-ios-sdk-cache \
  Sources/MSDKIOSCore/Telemetry.swift
python3 tools/check_repository.py
```

**PASS:** core source type-checks for the arm64 iOS 16 deployment target using Xcode **27.1** (`27A9275`) and iPhoneOS SDK **27.1**. This is compiler validation only: no signed app, install, device execution or accessory communication.

**PASS:** 17 Markdown files, 39 local link targets and 2 JSON files checked. External URLs and Markdown anchors are outside the local checker. An independent source review found one inconsistent repetition count; it was corrected to five cold and five separately recorded primed runs throughout the plan.

### Hosted CI

[GitHub Actions run 41542956868](https://github.com/bibek849/msdk-ios-lab/actions/runs/41542956868) completed successfully for initial commit `abfa0609210b266c175990be3eaced5ce1374203`.

Commands executed on the pinned Linux Swift image:

```sh
swift --version
swift test
swift run msdk-ios-replay
```

**PASS:** Swift 6.0.3 (`swift-6.0.3-RELEASE`), 16 tests with zero failures, and three synthetic replay samples. The separate document job also passed `python3 tools/check_repository.py`. Both jobs used read-only repository permissions. No credentials, iOS signing or physical devices were involved.

This closes the initial Linux/exact-toolchain software check only. The evidence commit updating this document does not change Swift source or fixtures.

### Remaining checks

| Layer | Status |
|---|---|
| iOS SDK type-check | PASS; compiler only |
| Documentation links / JSON | PASS; local targets and JSON syntax only |
| Hosted CI / Linux / exact Swift 6.0.3 | PASS for the linked initial commit |
| Signed iOS app / iPhone 15 Pro Max accessory probe | NOT RUN |
| Android MSDK 5.18.0 reference baseline | NOT RUN |
| DJI cold start, telemetry, video, camera/gimbal, flight, RC takeover | NOT RUN |
| Unity / headset / other consumer integration | NOT RUN; outside this initial foundation |

Follow [HARDWARE_TESTING.md](HARDWARE_TESTING.md) before requesting device work. SDK-derived evaluation publication remains subject to the stage-0 permission decision; synthetic results above contain no vendor evaluation.
