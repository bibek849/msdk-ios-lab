# Test results

## Contributor event inbox: live pilot — 2026-11-02 America/New_York

**PASS: GitHub → signed receiver → D1 → authenticated Python client**, for `bibek849` on this public repository. This qualifies notification delivery only. The maintainer does not need Claude Code; contributors may independently use the optional Claude adapter or another agent. Actual Claude execution and physical hardware remain **NOT RUN**.

Receiver source: `e640747b3a84e058a0221bb6299d9af33a4a7890`, with subsequent changes limited to setup-origin validation and documentation. Worker `msdk-ios-lab-inbox`, version `fb42ccd9-f9ef-4751-9da4-da858b8917da`, serves [the health endpoint](https://msdk-ios-lab-inbox.onrampyadav.workers.dev/health). GitHub App `5588168` / `msdk-ios-lab-inbox-bibek849`, installation `178014955`, is installed on **only** `bibek849/msdk-ios-lab`, with read-only Issues, Pull requests and Metadata permissions. No App private key or AI credential was deployed.

Cloudflare Workers Free was verified in the account dashboard. Only the new Worker and dedicated D1 database were created; existing applications, DNS, domains and billing settings were not modified. The student-offer instructions were opened for inspection, without enrollment or a paid-plan change.

Deployment commands from `services/agent-inbox`, using isolated Wrangler authentication and the ignored configuration pinned to the new pilot database:

```sh
node_modules/.bin/wrangler d1 create msdk-ios-lab-inbox-pilot
node_modules/.bin/wrangler d1 migrations apply msdk-ios-lab-inbox-pilot --remote --config wrangler.pilot.jsonc
node_modules/.bin/wrangler deploy --config wrangler.pilot.jsonc
node_modules/.bin/wrangler secret bulk /PRIVATE/PILOT/worker-secrets.json --config wrangler.pilot.jsonc
node_modules/.bin/wrangler deploy --config wrangler.pilot.jsonc
```

`/PRIVATE/PILOT` redacts the local private directory, not command behavior. The first deployment was disabled; the final deployment used the observed installation ID and enabled the pilot after its two secrets were installed. The remote migration executed seven commands successfully. An initial deployment attempt lacked `workers_scripts:write`; it failed without changing an existing Worker. Adding that required Wrangler scope allowed publication. A setup signing secret was replaced before production use after a diagnostic revealed it; no credential value is included in this repository.

Health returned HTTP 200 with `mode=notification_only`; unauthenticated inbox access returned HTTP 401; the configured client returned schema 1 for `bibek849`. A raw Python default user-agent probe initially received Cloudflare edge error 1010; the documented client user agent succeeded. These observations do not establish universal network reachability.

Live fixtures: [issue #10](https://github.com/bibek849/msdk-ios-lab/issues/10) and [PR #11](https://github.com/bibek849/msdk-ios-lab/pull/11).

| Live check | Observed result |
|---|---|
| Issue assignment and opening | Inbox IDs 1 and 2; assignment delivery `7f12c2d0-d71f-11f1-98d8-eacd8a32fa6a` |
| PR opening | Inbox ID 3, correct PR number and source SHA |
| Labels and ordinary comment | IDs 4–6; comment `6592309451` preserved its GitHub reference |
| Synthetic maintainer hardware marker | ID 7, `kind=hardware_feedback`, comment `6592309816`; body explicitly says hardware NOT RUN |
| Review and inline comment | IDs 8–9, review `5745482823`, comment `4449510595` |
| Resolved review thread | ID 10, `pull_request_review_thread.resolved` |
| GitHub assignment redelivery | HTTP 200 with `{"status":"accepted","duplicate":true,"id":1}`; one retained row for the delivery |
| Explicit acknowledgment | Ack IDs 1–9 removed exactly those pending records; ID 10 remained. Repeating ack ID 1 succeeded idempotently |
| Unassignment and closure | IDs 11 and 14 arrived after the task was unassigned; retained tracking also delivered the intervening label/comment events |
| Client restart and drain | Independent CLI processes fetched retained events; ack IDs 10–14 followed by fetch returned an empty pending list |

The actual CLI invocations used the private absolute config path; here it is intentionally redacted:

```sh
python3 tools/agent_inbox.py --config /PRIVATE/PILOT/client.json fetch --limit 20
python3 tools/agent_inbox.py --config /PRIVATE/PILOT/client.json fetch --limit 50
python3 tools/agent_inbox.py --config /PRIVATE/PILOT/client.json ack 1 2 3 4 5 6 7 8 9
python3 tools/agent_inbox.py --config /PRIVATE/PILOT/client.json ack 1
python3 tools/agent_inbox.py --config /PRIVATE/PILOT/client.json ack 10 11 12 13 14
python3 tools/agent_inbox.py --config /PRIVATE/PILOT/client.json fetch --limit 50
```

The assignment was recorded at `2026-11-03T00:42:51.451Z`, about 2.45 seconds after the payload's issue update timestamp. This single observation is not a delivery latency guarantee or a CPU benchmark. No sustained-load, free-quota exhaustion or production outage recovery test was performed.

[Hosted run 41554835049](https://github.com/bibek849/msdk-ios-lab/actions/runs/41554835049) passed all four jobs on the initial implementation revision: Swift 6.0.3 synthetic tests, local document links/JSON, contribution handoff tests and agent inbox service tests. The new inbox job is now required on `main`, preserving the existing three requirements and strict mode. Later PR revisions must independently pass these checks before merge.

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

**PASS: deployment dry run**, producing a 14.87 KiB Worker bundle (4.70 KiB gzip). The exact invocation was `WRANGLER_LOG_PATH=/private/tmp/msdk-inbox-final-build.log WRANGLER_SEND_METRICS=false npm run build`. `npm run build` invokes `wrangler deploy --dry-run`; it does not publish a Worker. **PASS: local D1 migration**, reporting seven executed commands against local state, using `WRANGLER_LOG_PATH=/private/tmp/msdk-inbox-migration.log WRANGLER_SEND_METRICS=false npm run db:local`. `npm run db:local` explicitly uses `--local`; no production database was migrated by this check.

The final `npm install --ignore-scripts --cache /private/tmp/msdk-agent-inbox-npm-cache` installation audit reported **zero known vulnerabilities** for the installed dependency graph after dependency overrides were applied. No separate post-fix `npm audit` run is claimed. Local tooling was Node 25.9.0 / npm 11.12.1 on arm64 macOS; CI uses pinned Node 22.23.4. This is an advisory-database result, not proof that the service is vulnerability-free. Exact package versions and transitive dependencies are recorded in the service package manifest and lockfile.

Independent integration review identified two schema/setup mismatches: invalid origin forms could pass initialization but fail client validation, and unsupported actor names could pass receiver normalization but fail client validation. Both boundaries were aligned and covered by the final local checks above. A final initializer review also rejected empty userinfo origins (`https://@pilot.example` and `https://:@pilot.example`); `python3 -m unittest discover -s tools/tests -p test_init_inbox_pilot.py -v` passed all three setup tests after that adjustment.

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
