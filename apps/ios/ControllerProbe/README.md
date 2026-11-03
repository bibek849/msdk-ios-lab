# ControllerProbe

ControllerProbe is a minimal diagnostic iPhone app for the M5 native probe ([#6](https://github.com/bibek849/msdk-ios-lab/issues/6), under [#4](https://github.com/bibek849/msdk-ios-lab/issues/4)). It observes, through Apple's public External Accessory API, whether a cabled controller becomes visible, which protocols it advertises, whether one session and its input stream open, and how many bytes arrive within 60 seconds.

It has no write, handshake, control, network or payload-logging path. The committed build is **BLOCKED** and declares no accessory protocol.

> **Verification status:** this app and its Xcode project were written on Ubuntu without Xcode.
> - Apple compilation, signing, installation and device execution are **NOT RUN**. The owner's H0 is the first Mac build.
> - The portable logic behind the app (`MSDKIOSAppleTransport` and `MSDKIOSProbeSupport`) passes its host tests.
> - The Apple-only adapter was type-checked against local API stand-ins only, which is not evidence of an Apple build.

## Requirements

- A Mac with **Xcode 16 or later**: the project uses the Xcode 16 format.
- An Apple developer team, either a Developer Program team or a personal team.
- The iPhone with Developer Mode enabled (Settings > Privacy & Security > Developer Mode).
- A clean checkout of the exact commit under test.

## Profiles

The run profile comes from build settings in `Config/Local.xcconfig`. That file is git-ignored and private, and its values override `Config/Probe.xcconfig`.

| `PROBE_RUN_MODE` | What the app may do | Requirements |
|---|---|---|
| `BLOCKED` (default) | Show the build and profile only. **No External Accessory call is made.** | — |
| `ENUMERATION_ONLY` | List the connected accessory and its advertised protocols. **No session is created.** | `PROBE_PERMISSION_BASIS` and a source SHA. If `PROBE_ACCESSORY_PROTOCOL` is set, it is declared for visibility only. |
| `SESSION_OBSERVATION` | The above, plus at most one session on `PROBE_ACCESSORY_PROTOCOL`, with only its input stream opened. Bytes are read in chunks of up to 4 KiB, counted and discarded. | `PROBE_PERMISSION_BASIS`, a source SHA, and one protocol that is also declared in `UISupportedExternalAccessoryProtocols` |

**Every run:**
- Lasts at most 60 seconds, retains at most 256 log entries, and stops at 1 MiB of input.
- Stops on an input-stream error or end, on disconnect, when the operator taps Stop, or when the app leaves the foreground.
- Must be started explicitly with a COLD or PRIMED cohort; a late callback cannot revive it.
- Leaves aircraft readiness, initialization and telemetry as **UNKNOWN**.

These are diagnostic limits, not properties of the accessory's protocol.

## H0: review, build, sign, install

1. Check out the exact commit under test and review this folder, `build-device.sh` and `Sources/MSDKIOSAppleTransport/`.
2. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` and set `PROBE_DEVELOPMENT_TEAM` and `PROBE_BUNDLE_IDENTIFIER`. Keep `PROBE_RUN_MODE = BLOCKED` for the first build.
3. Run `apps/ios/ControllerProbe/build-device.sh`. It refuses tracked changes, embeds `git rev-parse HEAD` as the source SHA, and prints:
   - the Xcode version;
   - the source SHA;
   - the app path;
   - the SHA-256 of the app executable.

   Record all four.
4. Install with `xcrun devicectl list devices`, then `xcrun devicectl device install app --device <device-id> <app path>`. Alternatively, open `ControllerProbe.xcodeproj` and Run on the phone.
5. Launch the app and confirm three things:
   - the screen shows `Source: <40-character SHA>` and `Activation: BLOCKED: PROFILE_BLOCKED`;
   - **Start is disabled**;
   - no accessory section appears.

   This is the H0 check of the default build.
6. Privately record the iOS version and build, the cable, the RC-N3 and Mini 4 Pro firmware versions, the DJI Fly version and the signing team type. Keep serial numbers and signing material out of shared reports.

## H1: only with prerequisites and an approved profile

Follow `experiments/H1-NATIVE-TRANSPORT-PROBE.json` at the same commit. The detailed cohort plan is in the native access dossier in [PR #16](https://github.com/bibek849/msdk-ios-lab/pull/16).

1. Record the owner's permission decision. Then set `PROBE_RUN_MODE`, `PROBE_ACCESSORY_PROTOCOL` (session mode only) and `PROBE_PERMISSION_BASIS` in `Local.xcconfig`. Rebuild with `build-device.sh`: the source SHA stays the same, the executable hash changes, and both go in the record.
2. Bench: propellers removed, operator present, the phone unlocked and in the foreground, and the RC-N3 cable connected throughout.
3. **Five COLD runs first:**
   - Power-cycle the RC-N3 and the aircraft.
   - Do not launch DJI Fly in that boot sequence.
   - Wait 30 seconds, launch ControllerProbe fresh, choose **Cold** and tap Start.
4. **Then five PRIMED runs, as a separate cohort:**
   - Use DJI Fly until it shows the aircraft connected, then terminate Fly from the app switcher.
   - Wait 10 seconds, launch ControllerProbe fresh, choose **Primed** and tap Start.
5. After each run, use **Copy run record** and store the text with that run's record. Force-quit ControllerProbe between runs.

**Stop conditions:** stop on any motor activity, a controller or aircraft state change, an unexpected prompt, a crash, a blocked write attempt, or anything outside this plan. If the profile or permission is not ready, complete H0 and record H1 as **BLOCKED**.

## What the run record contains

The run record contains:
- the source SHA, activation, cohort, origin `LIVE` and the window;
- for each layer, whether it was reached and when, relative to the start;
- counts of reads, bytes, zero-byte and failed reads, and bytes-available events;
- input and output stream states;
- the three readiness values (always UNKNOWN for live runs);
- the end reason, cleanup time, flags, the retained-entry count and the late-callback count.

It never contains payload, protocol names, accessory names or serial numbers. Accessory name, model, firmware and protocol names appear only in the on-screen private inventory section.

## If the project does not open or resolve

- **"Missing package product":** use File > Packages > Resolve Package Versions. If that doesn't help, remove the local package and add it again with File > Add Package Dependencies > Add Local, choosing the repository root. Then link `MSDKIOSAppleTransport` and `MSDKIOSProbeSupport` to the ControllerProbe target.
- **Xcode older than 16:**
  1. Create a new iOS App project named `ControllerProbe` (SwiftUI, Swift) in a temporary folder.
  2. Replace its sources with the two files in `ControllerProbe/`.
  3. Set the target's base configuration to `Config/Probe.xcconfig`, `INFOPLIST_FILE` to `Config/Info.plist`, and `GENERATE_INFOPLIST_FILE` to NO.
  4. Add the repository root as a local package.

  Record this deviation in H0.
