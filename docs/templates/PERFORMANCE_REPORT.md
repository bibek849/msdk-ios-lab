# Performance experiment

Status: PROPOSED / MEASURED / INCOMPLETE. Delete unused options. This template is not a performance result.

## Question and predeclared budget

- PR / experiment ID / component / language:
- Concrete bottleneck or question:
- Baseline and proposed approach; why simpler alternatives are insufficient:
- Workload: source provenance, input sizes/rate, codec/profile if relevant:
- Target metric, unit, measurement endpoints and pass/fail budget:
- Memory/queue bounds and overload/drop behavior:
- Correctness, recovery and authority invariants that must remain true:

## Reproduction

- Baseline and candidate full source commits / artifact SHA-256:
- Compiler, dependency pins, build configuration and optimization settings:
- Exact commands, harness/fixture identity and random seeds:
- Host or physical device / OS / aircraft-controller firmware as applicable:
- Thermal/power/background conditions; cold or warm session:
- Warm-up, measured duration, repeats and sample count:
- Instrumentation and its overhead / clock basis / synchronization uncertainty:
- Stop condition and local operator agreement if a hardware run is needed:

## Results

| Metric (units and endpoints) | Baseline | Candidate | Sample count / uncertainty | Meets budget? |
|---|---|---|---|---|
| p50 / p95 / p99 latency | NOT RUN | NOT RUN | Unknown | Unknown |
| Observed max / jitter / missed deadlines | NOT RUN | NOT RUN | Unknown | Unknown |
| Throughput / dropped or rejected items | NOT RUN | NOT RUN | Unknown | Unknown |
| Queue depth / oldest item age | NOT RUN | NOT RUN | Unknown | Unknown |
| CPU / allocation rate / memory growth / copy cost | NOT RUN | NOT RUN | Unknown | Unknown |
| Thermal / energy observations | NOT RUN | NOT RUN | Unknown | Unknown |

- Correctness/recovery tests and outcomes:
- Limitations and unmeasured metrics:
- Result: retain baseline / accept candidate / more evidence needed:
- Raw evidence location and permitted publication scope:
- Compatibility claims this result does **not** establish:

For video, report ingress, decode, presentation and optical timing separately. Synthetic/replay measurements remain labeled as such. Do not publish private or restricted SDK evaluation material without the existing rights/privacy review. Follow [ENGINEERING_STANDARD.md](../ENGINEERING_STANDARD.md).
