# Maintainer playbook

The maintainer turns remote software work into reliable local evidence. The initial physical target is **iPhone 15 Pro Max + RC-N3 + Mini 4 Pro**; its exact OS/firmware and transport details remain pending. No hardware checks have passed in this repository.

Use this playbook for queue management and feedback. Use [HARDWARE_TESTING.md](HARDWARE_TESTING.md) for the actual stage gates and device procedures.

## Give contributors a task they can finish

A ready task names one question, acceptance criteria, relevant files, the available synthetic baseline and the hardware dependency, if any. Include the expected contributor environment. For example: "Add a deterministic fixture proving that a rejected packet cannot advance accepted sequence state; run existing tests; no iOS device needed." Avoid assigning "port MSDK to iOS" as one issue.

Start with a few well-scoped tasks instead of a large empty board. Keep independent software, research and hardware lanes available so contributors can continue while a device question is blocked. A claim should have a named human owner and a short plan; if that person becomes unavailable, ask before reallocating overlapping work. There is no automatic ownership expiry or promised response-time SLA.

Before assigning implementation, require the [component decision](templates/COMPONENT_DECISION.md): why the next iOS capability needs it, what can be reused and the specific incompatibility to address. Compatible code stays in place; language defaults govern necessary new code.

For an opted-in agent contributor, assign their human GitHub account and link the task brief, following [the event workflow](AGENT_EVENT_WORKFLOW.md). Ask external contributors to comment first so they can be assigned without upstream write access. Keep scope changes and approved hardware feedback on the linked issue/PR; update current labels when blocked, reassigned or complete. Receiving a notification never grants device or merge authority. No central agent listener is configured.

## Track state explicitly

Use the labels below, keeping one `status:` label at a time and linking the task's PR and run records. Also use `hardware: not-needed` or `hardware: owner-run` to show the validation lane. These labels record decisions; no bot automatically verifies the transition.

| State / label | Meaning / next action |
|---|---|
| `status: ready` | Scope and acceptance criteria are clear; contributor can begin |
| `status: in-progress` | A human contributor owns the work; draft PR or progress reference is linked |
| `status: review` | Patch and software evidence are ready for maintainer review |
| `status: needs-changes` | Review or test feedback names a concrete next change |
| `status: hardware-queued` | Software review passed and an exact experiment revision is accepted into the local queue; no run has occurred |
| `status: hardware-results` | A run exists; its outcome and publication-approved next question are being reconciled |
| `status: blocked` | A named prerequisite, permission or unavailable interface prevents progress |
| Closed issue | The issue's own acceptance criteria are met; the completion record states software-only or the exact hardware scope |

A contributor may propose a state. The maintainer decides entry to the hardware queue and accepts device evidence. Green CI does not change a hardware state automatically.

## Keep the hardware queue manageable

Begin with **one device run active and at most two accepted experiments waiting**. This is a starting capacity policy, adjustable when the maintainer has more time or hardware. New requests stay in review until a slot is available. Group runs only when they use the same setup and retain separate identities and outcomes. Publish the next planned test window only when one is actually available; do not promise immediate device access.

Prioritize experiments that remove a shared blocker, then small repeatable failures, then new capability work. Defer requests lacking exact source identity, testable pass/fail criteria, finite duration, cleanup steps or the relevant stage permission. Return the missing item directly so the contributor can improve the request without guessing.

## Review before building on the hardware owner's machine

Check the diff, dependency changes, package/build scripts and workflow changes as code. Verify that the proposed test belongs to the current stage and that declared observations cannot silently execute commands. Review the exact source commit before building or attaching hardware; a contributor's artifact hash proves identity, not trustworthiness.

Keep untrusted fork testing on hosted, disposable CI without signing credentials or access to the aircraft network. Do not configure an automatic self-hosted runner on the owner's Mac, phone or drone network for arbitrary PR code. The [CI guidance from GitHub](https://docs.github.com/en/actions/reference/security/securely-using-pull_request_target) explains the distinction between ordinary fork PR execution and privileged workflow contexts. An approved CI run is still not permission for a device run.

For current original software-only changes, review and passing changed-layer checks can be enough to merge. For hardware-dependent behavior, keep the relevant issue open until device evidence exists. If an experimental foundation is merged first, its adapter stays unavailable or explicitly opt-in as appropriate, and no compatibility claim advances.

## Execute one frozen experiment

1. Confirm the full source commit and experiment checksum from the handoff. Inspect it against the reviewed PR revision. Record the PR head SHA, base SHA and tested CI commit where applicable: a workflow testing a merge result does not establish that the standalone head is the same tree. Build the declared exact revision. If the intended build uses a merge result instead, freeze that commit and regenerate the handoff. A rebase, changed PR head or new source revision requires review and a revised handoff before the queued test runs.
2. Build and sign locally using the recorded environment. Retain signing assets privately. Record the artifact SHA-256 and verify which artifact is installed; metadata files do not perform this step.
3. Record the hardware/OS/firmware/cable tuple, prior gates, cohort, allowed actions and local stop method in [the hardware-run record](templates/HARDWARE_RUN.md). Preserve unknown fields as unknown. Do not start a dependent run with a missing prerequisite.
4. Run only the bounded procedure. Record actual observations and cleanup, including failures and incomplete runs. If the procedure needs a new write/action, stop and review an updated experiment rather than expanding it during the run.
5. Keep the raw report in the private evidence location until rights and privacy decisions permit release. Create a concise [feedback record](templates/TEST_FEEDBACK.md) containing only material cleared for the contributor's intended use.
6. Update the issue state and the capability ledger only to the extent established. Use PASS, FAIL, BLOCKED, INCOMPLETE or NOT RUN precisely. A source fix does not change the outcome of an already tested artifact.

## Make feedback actionable for someone without the device

Give the contributor one observed-versus-expected difference, the relevant state transition or sequence, the exact tested revision and the smallest next hypothesis. An approved synthetic timeline is often more useful than pages of logs. If original evidence cannot be shared, say what is unavailable and provide only an independently authored reproduction that is permitted to share.

For example, a hypothetical software failure can be expressed as "session A closes; a late session-A sample arrives after session B begins; expected rejection, observed acceptance." A new synthetic fixture can model this sequence without publishing aircraft identifiers or raw SDK packets. This example is not a hardware observation from this project.

The contributor adds a failing regression, fixes the behavior and submits a new revision. Retest hardware only when the changed behavior or unresolved concern justifies it; do not require every documentation fix to consume a device slot.

## Maintain a credible public project

- Keep the README's working features, experiments and unavailable capabilities explicit. Link evidence to a revision and combination.
- Credit meaningful code, test, research and review contributions. Judge generated and manually written changes by the same behavior and evidence standards.
- Record architectural changes with the problem, decision, alternatives and consequence; small implementation choices need no separate ceremony.
- Publish software releases only with reproducible checks and explicit hardware scope. A new version number does not qualify flight or broaden the compatibility matrix.
- Keep issues small, explain closed experiments and preserve useful negative findings. Be clear when a result cannot be published.
- Treat changes to contributor permissions, repository rules or CI trust boundaries as deliberate project administration. Documentation of a desired rule is not evidence that a GitHub setting has been configured.

For an individual maintainer, requiring approval from a second independent maintainer before every merge can create a dead end. Start with contributor review discipline and CI, and introduce a second required human review when a second active maintainer can actually provide it. Keep any configured GitHub protections and their exceptions documented accurately.
