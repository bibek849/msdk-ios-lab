# AI-assisted contributor task

Fill this brief from an agreed issue, then give it to your agent. Public repository content and original synthetic material are the default inputs. Keep personal accounts, private device evidence, signing assets and restricted vendor material outside the prompt.

## Brief

- Issue / backlog ID:
- Human contributor:
- Base commit:
- Roadmap stage:
- Question to answer:
- Environment available: Linux/cloud Swift / Mac Xcode / edits only / other:
- Scope: software-only / hardware-dependent proposal:
- Relevant files and public references:
- Required behavior and acceptance criteria:
- Existing reproduction or fixture, with provenance:
- Changes outside this task:
- Checks to run; checks this environment cannot run:
- Stop condition and resource/time budget, if the contributor chooses one:
- Expected output: focused patch, tests, evidence summary; hardware request only if applicable:

## Paste-ready agent instruction

> Read AGENTS.md, README.md, CONTRIBUTING.md, docs/AI_CONTRIBUTOR_WORKFLOW.md and the relevant roadmap stage. Work only on the agreed task above. Inspect the current implementation and tests before editing. Reproduce the baseline where the environment supports it.
>
> Implement the smallest coherent change that answers the question. Add a meaningful regression for changed behavior and keep the existing provenance, units, missing-value, session and freshness boundaries. Do not add device commands, network services, vendor dependencies or new features unless they are explicitly in scope. Verify current API claims against primary sources when needed.
>
> Run available checks and report exact commands, environment and outcomes. Mark unavailable checks NOT RUN. Do not infer hardware success from compilation, mocks, replay or CI. If progress depends on hardware or unavailable permission, stop that dependent work and return the smallest concrete question; finish independent software work that is still within scope.
>
> Return a concise handoff: what changed and why, files changed, tests and results, remaining limitations, source/license provenance and any proposed next experiment. Do not export private prompts, account information or complete chat histories. Do not publish, contact people or operate hardware on my behalf unless I explicitly authorize that action.

## Human review before submitting

- I can explain the changed behavior and why the test demonstrates it.
- I inspected the diff, dependencies and new scripts.
- I checked cited APIs and provenance where they affect the change.
- I separated performed checks from unrun checks and hypotheses.
- The PR contains no private evidence, credentials or unauthorized vendor material.
- Any hardware request has a frozen source identity and a bounded procedure.

## Example scope

**Software-only example:** extend LAB-004 with an original deterministic test for one accepted-sequence boundary. Relevant files: `Sources/MSDKIOSCore/Telemetry.swift` and `Tests/MSDKIOSCoreTests/TelemetryTests.swift`. Preserve the existing rejection behavior. Demonstrate the chosen boundary with `swift test`; report iOS and DJI tests as NOT RUN. No transport, video, SDK integration or hardware access is needed.
