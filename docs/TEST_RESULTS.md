# Test results

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

### Remaining checks

| Layer | Status |
|---|---|
| iOS SDK type-check | PASS; compiler only |
| Documentation links / JSON | PASS; local targets and JSON syntax only |
| Hosted CI / Linux / exact Swift 6.0.3 | Configured; not yet observed |
| Signed iOS app / iPhone 15 Pro Max accessory probe | NOT RUN |
| Android MSDK 5.18.0 reference baseline | NOT RUN |
| DJI cold start, telemetry, video, camera/gimbal, flight, RC takeover | NOT RUN |
| Unity / headset / other consumer integration | NOT RUN; outside this initial foundation |

Follow [HARDWARE_TESTING.md](HARDWARE_TESTING.md) before requesting device work. SDK-derived evaluation publication remains subject to the stage-0 permission decision; synthetic results above contain no vendor evaluation.
