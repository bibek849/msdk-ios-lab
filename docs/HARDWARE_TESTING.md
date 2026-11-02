# Remote contribution, local hardware validation

**Current result: all hardware checks in this repository are NOT RUN.** Historical tests from another project are not results for this repository. Hardware owners run tests locally; remote contributors do not receive unattended control of an aircraft.

## The contribution loop

1. A contributor takes one [backlog task](CONTRIBUTOR_BACKLOG.md), states its hypothesis and supplies software tests or a synthetic reproduction.
2. The contributor opens a small PR containing the exact source revision, build commands, dependency versions and a proposed bounded test procedure. No SDK binaries, credentials or private captures belong in the PR.
3. A maintainer reviews the change and its applicable stage gate. A successful compile is not permission to exercise a device.
4. The maintainer builds the exact revision locally where possible, records the artifact SHA-256, confirms the device/firmware/cable combination, and runs only the agreed procedure.
5. The maintainer records **PASS**, **FAIL**, **BLOCKED**, **INCOMPLETE** or **NOT RUN**, including expected versus observed behavior and abort reasons. Failures remain part of the record.
6. A redacted, publication-approved result returns to the contributor. When SDK evaluation disclosure rights remain unresolved, retain the report privately and share only material cleared for release. A synthetic reproduction may be published independently.
7. Fixes receive a new source/artifact identity and a new run. Never overwrite the failed run or treat a source fix as an installed-binary result.

Use [templates/HARDWARE_RUN.md](templates/HARDWARE_RUN.md) for each run. Store private reports outside the public repository; ignore rules are a convenience, not a guarantee against accidental publication.

## Before a hardware slot

- Record the source commit, dependency lock/pin, build environment, package identifier and artifact digest. Hardware testing must use that exact artifact.
- Record aircraft/controller model and firmware, phone/tablet model and OS, accessory/cable route, power state and test stage. Keep serials, account identities, precise location and raw captures private.
- Establish whether the operation is observation, camera/gimbal actuation or flight. Obtain local operator approval for any action and a specific procedure; a past approval does not grant future flight authority.
- Resolve the applicable SDK permission and evidence-publication questions. DJI's [published EULA](https://developer.dji.com/policies/eula/) places conditions on SDK use and evaluation disclosure; this project does not assume that an MIT license on its own code grants rights to DJI material.
- Confirm how the operator will stop the run and restore ordinary controller operation. No background process or reconnect may restore software authority automatically.

## Initial test matrix

| Run | Prerequisite | Bounded procedure | Pass evidence | Abort/fail evidence |
|---|---|---|---|---|
| H0 inventory | No device communication required | Record the exact proposed combination and obtain missing iOS/signing details | Complete inventory with unknowns explicitly identified | Assumed firmware, unsupported capability claim or missing iOS target |
| H1 native transport probe | S0 permitted/documented route | Five cold starts without Fly and five separately recorded primed comparisons; maximum 60-second observation window each | App-visible transport/session identity and clean close per run; independently initialized cold runs pass | Unavailable entitlement, undocumented requirement, crash or unexpected output; primed-only success does not pass cold initialization |
| H2 Android reference | S0 SDK-use decision; independent 5.18.0 build | Up to 60 seconds of read-only registration/product/telemetry observation, then disconnect | Separate controller/aircraft presence and actual field availability, with artifact identity | App instability, unexpected action or loss of operator visibility |
| H3 iOS telemetry | Native H1 pass | Up to 60 seconds of observations; disconnect and start a fresh session | Correct units/missing values; stale old session rejected; new session explicitly started | Old values marked fresh, identity mismatch or reconnect restoring authority |
| H4 video | S3 gate | Up to 120 seconds on the bench; interrupt/restart the stream | Advancing frame IDs/content; measured codec/dimensions; independent video age; bounded buffering | Frozen frame marked live, growing queue, unexplained thermal event or crash |
| H5 ground command | S5 authority/takeover gate and approved action | One explicitly supported camera/gimbal request, then release; test rearm separately | Request/acceptance/acknowledgment/observed effect distinguished; takeover remains authoritative | Any unrequested action, failed revocation, stale intent acceptance or silent rearm |

H0–H4 grant no command authority. H5 excludes motor start, takeoff, landing/RTH initiation and flight; if a required prerequisite cannot be tested safely on the ground, H5 remains blocked. Flight gets a separately reviewed S6 procedure after relevant prior gates pass.

The durations above cap early experiments; they are not reliability or performance qualification. Establish longer repeatability/soak criteria only after the basic route works.

## Cold versus primed sessions

The primary native target is **iPhone 15 Pro Max + RC-N3 + Mini 4 Pro**; the iOS version/build, firmware and cable details remain to be recorded. A cold run starts after controller/aircraft power cycling and a new test-app session. Do not launch DJI Fly or reuse a Fly-prepared connection in that boot sequence. Record failure to initialize as a result, not a reason to silently prime the device.

Perform five independent cold runs before any primed comparisons. Record five primed runs as a separate cohort only if the approved procedure permits it; document exactly which initialization step was introduced. A claimed RC-N3/Neo precedent from the shared discussion is a hypothesis for investigation, not evidence for Mini 4 Pro. If the primed cohort succeeds and the cold cohort fails, transport access may have been demonstrated but native initialization remains blocked.

Use only the reviewed initialization needed to establish read-only observation. No discovery probe may explore flight commands or unknown writes. Stop at an unavailable permission or unexplained behavior rather than expanding the test on the fly.

## Measurements and evidence

Treat **MOCK**, **REPLAY** and **LIVE** as different provenance. Replaying a hardware recording remains REPLAY, with its recorded origin separately identified. Missing telemetry is unavailable, not zero. Use metric units, session/sequence/frame IDs, and an explicit clock basis.

Measure ingress, decode and presentation separately. Requested resolution/frame rate, callback counts and configured defaults are not delivered video measurements. SDK acknowledgment is not observed aircraft behavior. Record every unknown rather than filling it from another model or firmware.

Publish original synthetic fixtures and tests by default. Publication of hardware SDK evaluation results, raw traces and derived fixtures requires a documented rights and privacy decision. Never publish application keys, access tokens, account/aircraft serials, precise flight locations or private media as part of ordinary CI.
