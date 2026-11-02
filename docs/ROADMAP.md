# Incremental roadmap

Status: **research foundation, 2026-11-02**. No device combination has passed this project's hardware gates. Stages advance on evidence, not elapsed time.

## Two tracks, one honest destination

**Native track:** investigate whether a normally provisioned iOS application can communicate directly with a supported controller. Apply the [reuse-first policy](PORTING_POLICY.md) to each required component: preserve compatible, permitted code and implement only missing iOS boundaries or necessary incompatible parts. This is the primary research question.

The first native approach is a narrow implementation of a demonstrated transport and initialization path, selected after the component reuse assessment. Original code fills gaps only where permissions and evidence permit it; no reusable SDK core has been established. A separate, rights-gated binary-rehosting spike may examine whether Android binary format, ABI, runtime and Apple execution requirements can be satisfied. General rehosting precedents are not evidence that DJI's libraries run on iPhone; keep this spike bounded and do not let it consume the read-only native investigation.

**Independent cold start is a core gate:** the application must initialize a freshly powered controller/aircraft session without DJI Fly first preparing it. A connection that works only after Fly is a diagnostic lead, not a native-port success. The [shared discussion's](https://chatgpt.com/share/6ae91470-a894-83e9-b9c8-56fd67b81f81) RC-N3/Neo initialization report is an unverified lead for a different aircraft; it cannot establish Mini 4 Pro behavior.

**Reference track:** establish a reproducible Android MSDK **5.18.0** reference bench. An optional Android-to-iOS bridge can help compare contracts, telemetry and video. A bridge remains an Android dependency and does not close a native iOS gate. Do not make it the silent replacement for the project goal.

The open-source deliverables are original contracts, tools, fixtures and implementation. The official SDK is a separately licensed dependency, not code this project can relicense. See [DJI's SDK EULA](https://developer.dji.com/policies/eula/) and the [V5.18.0 repository license](https://github.com/dji-sdk/Mobile-SDK-Android-V5/blob/V5.18.0/LICENSE.txt).

## Stage gates

| Stage | Small deliverable | Contributor work | Local hardware test and exit gate |
|---|---|---|---|
| S0 — establish feasibility | Permission/provenance record, exact device inventory and transport decision | Audit official APIs and dependency licenses; identify a public iOS accessory route and a finite probe | Confirm actual iPhone/iPad, OS, cable, signing and controller combination. A normally provisioned app must access a documented transport; identify unresolved consent or entitlement needs. Record **GO**, **BLOCKED** or **NO-GO** per route. |
| S1 — reproducible software foundation | Original Swift telemetry contract and synthetic replay tests | Validate units, missing data, session identity, ordering, freshness and bounded input | No hardware needed. Tests must pass without DJI binaries, accounts or private captures. A software pass does not close S0 or establish device support. |
| S2 — Android reference baseline | Independently built, pinned 5.18.0 read-only bench | Build/reproduction instructions, narrow telemetry inventory and redacted evidence format | After S0 rights review, establish registration, controller AND aircraft presence, read-only telemetry and orderly disconnect on the exact combination. Keep SDK evaluation evidence private until publication rights are resolved. |
| S3 — direct iOS read-only connection | Native transport adapter and minimal observation path | Implement only the permitted, demonstrated route; use synthetic tests before device access | After S0 native GO, pass five independent cold starts without Fly priming; keep five primed comparison runs separate. Recover through an explicit new session. Obtain fresh, correctly identified telemetry without an Android relay. Missing or inaccessible fields remain unavailable. |
| S4 — video and camera observation | Video acquisition/decoding plus an independent camera capability inventory | Frame identities, stream lifecycle, bounded queues and independent telemetry/video freshness | Qualify video on its own: actual codec/dimensions, advancing frames, disconnect, background/resume and recovery. Inventory camera state separately. A video pass does not establish camera-command or flight support. |
| S5 — bounded ground actions | One approved nonflight action at a time, with authority and fault handling | Distinguish request, runtime decision, SDK acknowledgment and observed effect; reject stale/replayed intents | No motor start, takeoff or flight. First prove explicit grants, revocation and physical RC takeover on the applicable path; if takeover cannot be demonstrated, command acceptance remains blocked. Qualify a narrow camera/gimbal action only after a reviewed safe procedure. |
| S6 — controlled flight and qualification | Limited, separately approved flight experiment, then repeatability evidence | Bounds, watchdog behavior, fault matrix and per-combination release checklist | Requires every relevant previous gate plus local operator approval for the exact run. Qualify each flight action and takeover/rearm behavior separately. No automatic advancement from ground tests. |

S1 can proceed while S0 is unresolved because it uses only original synthetic data. SDK-dependent implementation or evaluation must respect the S0 permission decision. For S3, S2 is a useful comparison baseline, not evidence that iOS transport exists.

## First experiments

1. **Transport dossier:** start with the maintainer's iPhone 15 Pro Max and RC-N3. Record the actual iOS version/build, public API, required entitlement and manufacturer protocol documentation. USB-C connector presence is not proof of an application-accessible USB interface.
2. **Connection probe:** once the proposed route and permissions are established, perform five cold-start runs without Fly initialization and five separately identified primed comparison runs, using read-only observations and a maximum 60-second observation window per run. Cold runs begin with controller/aircraft power-cycled and a fresh test-app session; no Fly launch may occur in that boot sequence. Stop on an unexpected permission requirement, crash, controller mode change or unexplained write. Primed-only success keeps the independent-initialization gate open.
3. **Reference snapshot:** after the rights gate, run a short Android read-only session with exact SDK and firmware identities. Compare only the explicitly requested fields. Do not import the private product's earlier results as this project's evidence.
4. **Replay handoff:** give a remote contributor a synthetic fixture and a failing contract test. Require a reproducible fix before allocating a hardware slot.

## Stop and pivot rules

- If the direct route needs an unavailable entitlement, unsupported accessory protocol or unresolved rights, mark native work **BLOCKED** and record what would unblock it. Do not promise a full port or disguise the bridge as one.
- If a measured behavior contradicts a generic capability declaration, retain the failure and narrow the compatibility claim.
- If a stage fails, return to its smallest reproducible case. Later stages stay closed.
- If native feasibility fails, the public result can still be a documented limitation, portable Swift model and optional bridge research. Changing the primary objective requires an explicit project decision.

Work items are in [CONTRIBUTOR_BACKLOG.md](CONTRIBUTOR_BACKLOG.md); the local feedback loop is in [HARDWARE_TESTING.md](HARDWARE_TESTING.md).
