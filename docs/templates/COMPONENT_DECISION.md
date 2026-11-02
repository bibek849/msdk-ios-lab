# Component decision

Copy the relevant fields into an issue/PR or save a completed record with the change. Keep the scope small. Unknowns are acceptable; invented source access or compatibility is not. Follow [the porting policy](../PORTING_POLICY.md).

## Requirement and scope

- Issue / active roadmap stage:
- Required iOS capability and exact target combination:
- Component and its smallest required dependency boundary:
- Why this component is needed now; what remains deferred:

## Existing implementation and evidence

- Origin, exact version/commit or artifact hash:
- Available material: original source / authorized third-party source / binary / documented interface / unknown:
- License or permission basis, attribution and redistribution/publication limits:
- Existing implementation language, runtime, platform APIs and dependencies:
- Source portability evidence:
- Binary/build/deployment evidence for the required iOS target:
- Device behavior evidence (or NOT RUN):
- Unresolved assumptions and the smallest experiment that can resolve them:

## Decision

- Select one: DEFER / REUSE / REBUILD / ADAPT / PORT MINIMUM / IMPLEMENT MISSING CAPABILITY / INVESTIGATE / BLOCKED.
- Why this is the smallest sufficient intervention:
- For ADAPT or PORT MINIMUM: exact incompatible boundary, supporting failure/evidence, and why a smaller change is insufficient:
- For new original implementation: why no usable implementation exists and which permitted interface/behavior supports this work:
- Existing code retained unchanged:
- New or changed code, public-contract effects and dependency changes:
- Language decision for necessary new code; justification for any new toolchain:
- Alternatives considered and why they are unnecessary or insufficient:

## Verification and handoff

- Acceptance criteria for this component and stage:
- Source revision, compiler/SDK/build configuration and exact commands:
- Reused behavior / changed boundary regression tests:
- Results, artifact identities and limitations:
- Performance evidence if an improvement is claimed (use [PERFORMANCE_REPORT.md](PERFORMANCE_REPORT.md)):
- Hardware test needed: no / owner-run; exact unresolved question:
- Next prerequisite or stopping condition:
- Maintainer review reference and decision date:

A completed record is a design decision, not permission to run hardware. Use [the handoff workflow](../HANDOFF_FORMAT.md) when a device test is needed.
