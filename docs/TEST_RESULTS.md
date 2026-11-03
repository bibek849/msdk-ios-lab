# Test results

## M5: ControllerProbe source handoff (host checks only) — 2026-11-03

**Scope:** the first source handoff for the planned owner checkpoint on November 4 ([#4](https://github.com/bibek849/msdk-ios-lab/issues/4), [#6](https://github.com/bibek849/msdk-ios-lab/issues/6)). The component decisions are in [ADR 0003](decisions/0003-m5-controller-probe.md). It adds:
- the `MSDKIOSAppleTransport` target, with a portable run controller and profile and an Apple-only External Accessory binding;
- the `ControllerProbe` app, a hand-written Xcode project, `build-device.sh` and README in `apps/ios/ControllerProbe/`;
- the experiment descriptor `experiments/H1-NATIVE-TRANSPORT-PROBE.json`.

The M4 contract gains `RUN_STOPPED` with an explicit reason, and its `apply` uses typed throws. **The committed build is BLOCKED.** There is no write, handshake, network or payload-logging path.

```sh
swift --version
swift test
swift run msdk-ios-replay fixtures/synthetic-telemetry-v1.json
python3 tools/check_repository.py
python3 -m unittest discover -s tools/tests
git diff --check
```

**PASS on Swift 6.4.2** (x86_64 Ubuntu 26.04.1 VM):
- 55 tests passed with 0 failures: 16 telemetry, 22 observation-model and 17 run-controller tests.
- No compiler warnings.
- The replay CLI exited 0 with 3 samples and `delivery=REPLAY`.
- The repository check reported 43 Markdown files, 188 local link targets and 10 JSON files.
- The handoff tooling tests passed, and `git diff --check` was clean.

**PASS on Swift 6.0.3:** the same 55 tests passed, and the replay CLI exited 0. As in M4, this used the official 24.04 toolchain with a private `libxml2.so.2` shim, so it is not CI's container.

**Sensitivity check:** four alterations to the run controller, each restored before committing. Each was caught:

| Alteration | Failed assertions | Failing tests |
|---|---|---|
| The read length ignores the 1 MiB total | 1 | 1 |
| No stop on an input-stream error | 3 | 1 |
| Every read is retained in the log, so the event budget is hit before the read budget | 4 | 1 |
| Enumeration-only applies session events | 2 | 1 |

**Local checks, not committed:**
- `ExternalAccessoryProbe.swift` was type-checked on Linux with Swift 6.4.2 and 6.0.3, against hand-written stand-ins for the External Accessory and Combine names it uses. Object files contained the adapter's symbols, confirming its `#if canImport(ExternalAccessory)` branch compiled. **This checks Swift typing only. It is not an Apple SDK build.**
- The Xcode project's 23 objects all resolve.
- The scheme is well-formed XML and points at the defined target.
- `Info.plist` parses and has no background modes.
- `build-device.sh` passes `sh -n`.
- The experiment descriptor passes `tools/prepare_handoff.py` validation as `DRAFT`, with 9 pending owner items.

**NOT RUN:**
- Opening the Xcode project, Apple compilation, signing and installation.
- Any External Accessory call.
- Any iPhone, RC-N3, Mini 4 Pro or DJI Fly step.

These belong to the owner's H0 and H1.

## M4: probe observation contract (host-only) — 2026-11-03

**Scope:**
- A design note, [PROBE_OBSERVATION_CONTRACT.md](PROBE_OBSERVATION_CONTRACT.md), written before the code.
- A new library target, `MSDKIOSProbeSupport`, which depends only on `MSDKIOSCore`, and its test target `MSDKIOSProbeSupportTests`. There is no new product or dependency, and existing targets and the telemetry contract are unchanged.
- Three original fixtures in `fixtures/synthetic-probe/`, using `org.example.synthetic.*` protocol names.

The code performs no accessory, stream, network or device operation, and contains no vendor identifiers or packet data. It has no transmit path, and `ResearchCapabilities` is untouched.

**Base:** upstream `main` at `0fbc297df3c5db950efafa1aeb7ca05a64c5af1b`.

```sh
swift --version
swift test
swift run msdk-ios-replay fixtures/synthetic-telemetry-v1.json
python3 tools/check_repository.py
git diff --check
```

**PASS on Swift 6.4.2** (x86_64 Ubuntu 26.04.1 VM):
- `swift test` ran 38 tests with 0 failures: the 16 existing telemetry tests and 22 new probe tests.
- The new targets compile with no warnings.
- The replay CLI exited 0, accepting 3 samples with `delivery=REPLAY`.
- The repository check passed with 41 Markdown files, 182 local link targets and 9 JSON files.
- `git diff --check` was clean.

**PASS on Swift 6.0.3** (the CI pin): the same 38 tests passed with 0 failures, and the replay CLI exited 0. This used the official `swift-6.0.3-RELEASE-ubuntu24.04` toolchain, with its signature verified.
- This is **not** CI's environment. On Ubuntu 26.04, the 6.0.3 SwiftPM binaries need `libxml2.so.2`, so a private `LD_LIBRARY_PATH` entry pointed that name at the system's `libxml2.so.16`.
- No tested code uses FoundationXML.
- Hosted CI in the pinned `swift:6.0.3-jammy` container remains the reference.

**Sensitivity check:** the reducer was altered four ways and restored before committing. Each alteration was caught:

| Alteration | Failed assertions | Failing tests |
|---|---|---|
| A bytes-available event sets the first-read time | 2 | 1 |
| The run-identity check is removed | 7 | 2 |
| Opening the input stream also opens the output stream | 5 | 5 |
| The window end becomes exclusive | 3 | 2 |

Applying each observation to a copy is defense in depth. The reducer already completes every check before it changes anything, so removing the copy would not be detected by these tests.

**NOT RUN:**
- Any iOS or Xcode build.
- Any External Accessory or stream API.
- Any device, DJI Fly, RC-N3 or Mini 4 Pro step.

M5 is not approved.

## First external contributor inbox — 2026-11-02 America/New_York

**PASS: isolated receiver, signed GitHub delivery and authenticated client access** for `yout221496-ops`, GitHub numeric ID `351773451`. This is notification infrastructure evidence. Actual contributor Claude Code connection/tool invocation, scheduling and physical iPhone/DJI tests remain **NOT RUN** pending a separate result.

| Identity | Observed value |
|---|---|
| Worker / health | `msdk-inbox-351773451` / [HTTPS health](https://msdk-inbox-351773451.onrampyadav.workers.dev/health) |
| Deployed version | `675428f4-6155-4e98-8308-dbdcc387236e` |
| D1 database | `msdk-inbox-351773451`, UUID `725d7b1f-5131-479d-9dc8-2c48cf660d68` |
| GitHub App / installation | `5590050` / `msdk-lab-inbox-351773451` / `178061471` |
| Scope | Only `bibek849/msdk-ios-lab`; read-only Issues, Pull requests and Metadata; six event families |
| Explicit tracked issues | `4,13`; assignment preceded activation, so history must be reconciled on GitHub |
| Deployment checkout | `bd2b7f2f21bb448cf7299b31079bc71553da4b37`; no receiver-source or migration-schema changes |

Cloudflare Workers Free was verified in the account dashboard. Preflight found one D1 database and two Workers, and the selected new names were unused. Only the new recipient Worker/database were added; the existing owner pilot was not modified. No App private key was generated, no AI provider was called, and no billing setting changed.

The new database migration executed **seven commands successfully**. Health returned **200**, unauthenticated fetch returned **401**, and the authenticated Python client returned the correct recipient with **zero pending events** before the delivery test. These access checks are separate from the GitHub delivery evidence below and do not establish a contributor agent session.

Commands ran from `/Users/kraten/Documents/Playground/msdk-ios-lab` with pinned Wrangler **4.156.2** and isolated authentication. `/PRIVATE/PILOT` and `/PRIVATE/CONTRIBUTOR` redact private paths; every mutation selects the new recipient config. The first deployment was disabled; the final one followed installation-ID, tracked-issue and enablement configuration.

```sh
export XDG_CONFIG_HOME=/PRIVATE/PILOT/wrangler-auth
export WRANGLER_SEND_METRICS=false
export WRANGLER_LOG_PATH=/private/tmp/msdk-contributor-invite-wrangler.log
wrangler_bin=/private/tmp/msdk-agent-inbox/services/agent-inbox/node_modules/.bin/wrangler
"$wrangler_bin" d1 create msdk-inbox-351773451 --config /PRIVATE/CONTRIBUTOR/wrangler.contributor.jsonc
"$wrangler_bin" d1 migrations apply msdk-inbox-351773451 --remote --config /PRIVATE/CONTRIBUTOR/wrangler.contributor.jsonc
"$wrangler_bin" deploy --config /PRIVATE/CONTRIBUTOR/wrangler.contributor.jsonc
"$wrangler_bin" secret bulk /PRIVATE/CONTRIBUTOR/worker-secrets.json --config /PRIVATE/CONTRIBUTOR/wrangler.contributor.jsonc
"$wrangler_bin" deploy --config /PRIVATE/CONTRIBUTOR/wrangler.contributor.jsonc
python3 tools/agent_inbox.py --config /PRIVATE/CONTRIBUTOR/client.json fetch --limit 20
```

Recipient key provenance: [the contributor's public-key comment](https://github.com/bibek849/msdk-ios-lab/issues/13#issuecomment-6595251930), authenticated author ID `351773451`; SPKI SHA-256 `a37142d3a2540193cba20cfd08a7582a884e8f5edd2a62f953fe550822acb317`. Only the nonsecret invite and RSA-OAEP/SHA-256/MGF1-SHA-256 ciphertext may be published; the token and private key stay private.

The user-authorized [encrypted invitation](https://github.com/bibek849/msdk-ios-lab/issues/13#issuecomment-6595469738) was published and edited through the contributor-readable onboarding issue. A publication scan found neither the plaintext inbox token nor the webhook secret in the comment. Recipient-side decryption and connection remain **NOT RUN** until reported.

**PASS: real `issue_comment` created and edited events** from `bibek849` on issue `13` reached the new inbox as pending IDs `1,2`. Both were left **UNACKNOWLEDGED** for the contributor. The owner inbox still authenticated as `bibek849`; presenting each recipient token to the other recipient's endpoint returned **401 in both directions**. This establishes tested delivery/isolation, not Claude Code receipt, scheduling or hardware readiness.

Documentation verification: `python3 tools/check_repository.py` **PASS** (40 Markdown files, 181 local link targets, 6 JSON files); `git diff --check` **PASS**. No runtime code changed for this record.

## Contributor onboarding and agent adapter — 2026-11-02

Scope: a private-profile connector, offline recipient invitation preparer, local stdio MCP adapter, GitHub onboarding form and contributor/maintainer guides. The live Worker, database schema, existing App permissions and billing were not changed. No additional contributor was contacted or enrolled, and no AI-provider account was activated.

```sh
python3 -m unittest discover -s tools/tests -q
python3 tools/check_repository.py
git diff --check
```

**PASS: 70 Python tests**, comprising the prior 28 plus 19 connector, 9 invitation and 14 MCP tests. Local environment: Python 3.14.6, arm64 macOS; loopback permission was needed for HTTP fixtures. Connector tests verify both GitHub login and numeric identity, remote identity before credential persistence, private files, immutable profiles, checkout-independent runtime copies, shell quoting and diagnostic redaction. Invitation tests cover separate recipient secrets, disabled configs, correct public invite fields, known-pilot protection and no credential disclosure. MCP subprocess tests cover both supported protocol revisions, inert notification content, exact acknowledgments, malformed envelopes, frame bounds and failure redaction.

An initial integration run exposed an error-message redaction regression after improving setup diagnostics. Local onboarding errors are now distinguished from external client errors, and all 19 connector tests passed after the fix. The complete 70-test suite subsequently passed. A later official-SDK check found missing modern caching hints; those were added and all 14 MCP tests passed again. The final desktop setup-field addition passed the connector suite again. Hosted CI independently covers the final combined revision.

The [official MCP TypeScript client](https://ts.sdk.modelcontextprotocol.io/v2/get-started/first-client) was installed **only in a temporary interoperability fixture**, pinned to `@modelcontextprotocol/client@2.4.0`; Node was 25.9.0. It is not a repository runtime dependency:

```sh
npm install --prefix /private/tmp/msdk-mcp-sdk-interop \
  --save-exact --ignore-scripts --cache /private/tmp/msdk-mcp-sdk-cache \
  @modelcontextprotocol/client@2.4.0
node /private/tmp/msdk-mcp-sdk-interop/interop.mjs
```

**PASS:** default legacy `2025-11-25`, automatic modern `2026-07-28`, and explicitly pinned modern mode. Each verified status, fetch, explicit ack and error handling against a synthetic HTTP fixture. The SDK initially rejected a modern tool-list response without `ttlMs`/`cacheScope`; the adapter now supplies those required hints on modern discovery/tool-list responses and the SDK accepts them. The [modern caching specification](https://modelcontextprotocol.io/specification/2026-07-28/server/utilities/caching) is the contract. This is independent SDK interoperability, not proof of every agent product's behavior.

The new recipient bundle also passed a real Wrangler **dry run** with config outside the checkout:

```sh
WRANGLER_SEND_METRICS=false WRANGLER_LOG_PATH=/private/tmp/msdk-contributor-invite-dryrun/wrangler.log \
  /private/tmp/msdk-agent-inbox/services/agent-inbox/node_modules/.bin/wrangler deploy \
  --dry-run --config /private/tmp/msdk-contributor-invite-dryrun/wrangler.contributor.jsonc \
  --outdir /private/tmp/msdk-contributor-invite-dryrun/build
```

**PASS:** Wrangler 4.156.2, 14.92 KiB / 4.72 KiB gzip, synthetic recipient and database, `INSTALLATION_ID=0`, `PILOT_ENABLED=false`. This confirms the generated absolute-path config bundles correctly; no cloud deployment occurred.

### Existing pilot connection smoke test

The new connector successfully verified the existing `bibek849` GitHub identity and authenticated inbox, created a private temporary profile with copied runtime, printed token-free connection commands, and passed `doctor`. The private credential path is intentionally redacted below:

```sh
python3 tools/contributor.py connect \
  --invite /private/tmp/msdk-onboarding-live-invite.json \
  --token-file /PRIVATE/PILOT/inbox-token \
  --home /private/tmp/msdk-onboarding-live-profile-v2 --agent codex
python3 tools/contributor.py doctor --home /private/tmp/msdk-onboarding-live-profile-v2
codex --version
codex mcp add --help
```

**PASS:** `connected=true`, recipient `bibek849`; doctor reported `agent_registration=not_checked` and `hardware=NOT_RUN`. The installed Codex CLI was `0.166.0-alpha.5.1`; its help confirmed the generated `mcp add NAME -- COMMAND...` syntax. No Codex configuration was written and no model was invoked. A separate subprocess handshake/discovery/status/fetch check through the copied adapter reached the live inbox without acknowledgment. The prior live event pilot below remains the assignment/review/hardware-feedback transport evidence.

**NOT RUN:** actual Claude Code or Codex session tool invocation/scheduling, another human contributor's enrollment, new contributor cloud deployment, PR submission under another account, physical iPhone/DJI tests. The owner does not need an AI account for this workflow. Agent installation and scheduling remain explicit contributor choices; an MCP connection itself does not start an always-on observer.

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
