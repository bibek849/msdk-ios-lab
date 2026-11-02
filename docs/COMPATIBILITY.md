# Compatibility ledger

Snapshot: **2026-11-02**. This is a research target inventory, not a supported-device list. **Every hardware test in this repository is NOT RUN.**

## Available and proposed targets

| Component / route | Inventory position | This project's evidence |
|---|---|---|
| DJI Mini 4 Pro + RC-N3 | Maintainer-owned primary proposed bench combination | NOT RUN; exact firmware and individual capabilities must be recorded |
| Redmi Note 11 Pro 5G + Android MSDK 5.18.0 | Maintainer-owned Android reference host | NOT RUN; independent build and OS/dependency record required |
| iPhone 15 Pro Max | User-confirmed native target; iOS version/build, cable, signing and accessible transport pending | NOT RUN; USB-C does not establish generic app-accessible USB; no direct transport or SDK compatibility claim |
| iPad | Model, OS, cable, signing and accessible transport pending | NOT RUN; do not transfer an iPad result to iPhone |
| DJI RC-N2 | Not independently commissioned for this project | NOT RUN; separate qualification if selected |
| DJI RC 2 | Owned hardware context; not the chosen direct MSDK connection route | No support claim; not a substitute for RC-N3 tests |
| Android-to-iOS bridge | Optional reference experiment | NOT IMPLEMENTED / NOT RUN; a bridge is not a native iOS port |

Hardware availability is informed by maintainer project context. No code, private reports, captures or successful test status from that project has been imported here.

## Capability granularity

Track each capability against **aircraft model + aircraft firmware + controller model + controller firmware + mobile model/OS + app artifact + transport**. A result is not transferable to a similar product name.

| Capability | Native iOS | Android reference |
|---|---|---|
| App registration / permitted SDK initialization | NOT RUN | NOT RUN |
| Controller discovery | NOT RUN | NOT RUN |
| Independent cold initialization without DJI Fly | NOT RUN | NOT RUN |
| Aircraft connection | NOT RUN | NOT RUN |
| Each telemetry field and unit | NOT RUN | NOT RUN |
| Live video / actual codec / dimensions / advancing frames | NOT RUN | NOT RUN |
| Camera state observations | NOT RUN | NOT RUN |
| Camera and gimbal actions | NOT RUN | NOT RUN |
| Flight authority / RC takeover / explicit rearm | NOT RUN | NOT RUN |
| Flight actions and modes | NOT RUN | NOT RUN |
| Disconnect, background/resume and recovery | NOT RUN | NOT RUN |

Use **SUPPORTED_BY_SOURCE** only for a dated official statement about an exact feature; it remains distinct from **VERIFIED_ON_HARDWARE**. Use **UNAVAILABLE**, **BLOCKED**, **FAILED** and **UNKNOWN** where appropriate. A source listing a drone does not validate every controller, firmware or operation.

Record cold-start and Fly-primed sessions separately. Primed-only success cannot qualify independent native initialization. An RC-N3/Neo report from the shared discussion cannot be transferred to the Mini 4 Pro combination.

## Official baseline

DJI's [V5.18.0 Android sample README](https://github.com/dji-sdk/Mobile-SDK-Android-V5/blob/V5.18.0/README.md) is the pinned Android reference. Its device list includes Mini 4 Pro, but this project makes no broader compatibility inference from that list. The [official iOS SDK repository](https://github.com/dji-sdk/Mobile-SDK-iOS) is a separate SDK line; its existence does not establish iOS V5 support. Direct iOS feasibility must pass the route-specific S0 gate in [ROADMAP.md](ROADMAP.md).
