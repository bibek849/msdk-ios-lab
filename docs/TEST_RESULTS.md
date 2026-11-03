# Test results

## Contributor event inbox: local validation — 2026-11-02

Scope: a notification-only Cloudflare Worker/D1 receiver, the Python inbox client, private pilot setup and their tests. These checks use original synthetic GitHub payloads and temporary test credentials. They do not contact DJI, operate hardware, execute event instructions or establish live GitHub App delivery.

From the repository root:

```sh
python3 -m unittest discover -s tools/tests -v
```

**PASS: 28 Python tests** — 14 inbox-client tests, 11 existing handoff tests and 3 pilot-initialization tests. The client tests use a temporary loopback HTTP server to verify fetch/explicit acknowledgment, identity/schema/URL checks, pagination, redirect refusal, authentication errors, malformed/oversized responses, private-file permissions and inert event text. Setup tests verify private credential files, the token hash, read-only registration parameters, overwrite refusal and invalid-origin rejection. An initial sandboxed run could not bind the local HTTP fixture; the successful run permitted loopback sockets. No public HTTP service was started by these tests.

From `services/agent-inbox`:

```sh
npm run check
npm test
npm run build
npm run db:local
```

**PASS: TypeScript validation and 23 Miniflare/D1 integration tests.** Coverage includes signed assignment delivery; issue/PR routing; reviews, inline comments and hardware-feedback classification; bad signatures and repository/installation mismatches; duplicate/concurrent deliveries; exact, atomic and idempotent acknowledgment; recipient isolation; queue backpressure; bounded multibyte responses; streamed oversized bodies; disabled configuration; restart persistence; out-of-order observations; and actor normalization compatible with the Python client. Synthetic hardware-feedback events explicitly state hardware **NOT RUN**.

**PASS: deployment dry run**, producing an approximately 15 KiB Worker bundle. `npm run build` invokes `wrangler deploy --dry-run`; it does not publish a Worker. **PASS: local D1 migration**, reporting seven executed commands against local state. `npm run db:local` explicitly uses `--local`; no production database was migrated by this check.

The dependency audit reported **zero known vulnerabilities** for the installed dependency graph. This is an advisory-database result, not proof that the service is vulnerability-free. Exact package versions and transitive dependencies are recorded in the service package manifest and lockfile.

Independent integration review identified two schema/setup mismatches: invalid origin forms could pass initialization but fail client validation, and unsupported actor names could pass receiver normalization but fail client validation. Both boundaries were aligned and covered by the final local checks above.

### Evidence still required

| Layer | Status at this local checkpoint |
|---|---|
| Local synthetic Worker/D1 and Python suites | PASS as described above |
| Free-plan Cloudflare deployment and production D1 migration | NOT RUN |
| Registered/installed GitHub App and real signed webhook delivery | NOT RUN |
| End-to-end live assignment, review comment and synthetic feedback receipt | NOT RUN |
| Claude Code login, `/loop` scheduling and visible event consumption | NOT RUN |
| iPhone, DJI, flight, Unity/headset and hardware performance | NOT RUN; outside these tooling checks |

Record subsequent live results separately with the source revision, deployment/version and tested GitHub item identities. A successful inbox acknowledgment means receipt only; it is not task completion, code execution permission or hardware approval.

## Reuse policy and agent events — 2026-11-02

Scope: reuse-first component decisions, contributor instructions and event-subscription design. No runtime, dependency, CI configuration, installed scheduler or hardware integration changed.

```sh
python3 tools/check_repository.py
git diff --check
```

**PASS:** 33 Markdown files, 125 local link targets and 3 JSON files; no whitespace errors. The checker validates local targets and JSON syntax, not external URLs, anchors or event delivery. Independent review found no blocking issue; its wording correction now makes the CONTRIBUTING language defaults apply to necessary new code.

The documented read-only inbox commands were run against the public repository with the existing maintainer account:

```sh
gh issue list --repo bibek849/msdk-ios-lab --assignee @me --state all --limit 100 \
  --json number,title,state,labels,assignees,updatedAt,url
gh pr list --repo bibek849/msdk-ios-lab --author @me --state all --limit 100 \
  --json number,title,state,headRefOid,reviewDecision,statusCheckRollup,updatedAt,url
gh issue view 4 --repo bibek849/msdk-ios-lab \
  --json number,title,body,state,assignees,labels,comments,updatedAt,url
gh pr view 8 --repo bibek849/msdk-ios-lab \
  --json number,title,body,state,headRefOid,comments,reviews,reviewRequests,statusCheckRollup,url
gh api --paginate repos/bibek849/msdk-ios-lab/pulls/8/comments
```

**PASS:** all five commands exited 0 with parseable JSON. At that time the account had no assigned issues, two authored PRs, issue 4 and PR 8 were readable, and PR 8 had no inline review comments. This verifies command syntax and this account's read access only. It does not test another contributor's authentication, pagination at scale, event delivery, wake-up, cursor persistence or unattended execution.

No runtime tests were rerun locally for this documentation-only change; the required hosted workflow verifies the unchanged software suites on the PR separately. GitHub App/webhook deployment, automated agent delivery, native iOS compilation/execution, hardware, DJI and performance checks are **NOT RUN** for this change. No hardware compatibility or reuse of vendor internals is established.

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
