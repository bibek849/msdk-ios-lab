# Source and provenance register

Checked **2026-11-02**. These are research references, not bundled dependencies. No referenced implementation, vendor SDK, packet capture or binary is imported by this register. Community hardware claims are author reports and have not been reproduced by this project.

## Official DJI sources

| ID | Source / pinned identity | What it supports |
|---|---|---|
| D1 | [Android V5.18.0 README](https://github.com/dji-sdk/Mobile-SDK-Android-V5/blob/07d37cfdff865cdda9d523b00b723c9984575f8f/README.md), tag `V5.18.0`, commit `07d37cfdff865cdda9d523b00b723c9984575f8f` | Android SDK version and separate AAR dependencies; Mini 4 Pro listed. |
| D2 | [License at the same revision](https://github.com/dji-sdk/Mobile-SDK-Android-V5/blob/07d37cfdff865cdda9d523b00b723c9984575f8f/LICENSE.txt) | Sample code is MIT; SDK is governed by DJI's EULA. They are not interchangeable licenses. |
| D3 | [Official iOS README](https://github.com/dji-sdk/Mobile-SDK-iOS/blob/071cd3e1024d6a2ca025210983d0f4b043234cd1/README.md), commit `071cd3e1024d6a2ca025210983d0f4b043234cd1` | Checked iOS repository identifies 4.16.2. |
| D4 | [DJI SDK EULA](https://developer.dji.com/policies/eula/), page says last modified 2017-12-12 | Review §§3.2–3.3 for porting, modifications, disclosure and redistribution. Verify the terms attached to any acquired artifact. |
| D5 | [MSDK release notes](https://developer.dji.com/doc/mobile-sdk-tutorial/en/) | V5.18.0 notes dated 2026-05-22 list Mini 4 Pro with RC-N2/RC-N3; vendor-listed firmware is not owner verification. |
| D6 | [V5 product page](https://developer.dji.com/mobile-sdk/) and [V4 product page](https://developer.dji.com/mobile-sdk-v4/) | Reviewed platform listings distinguish Android V5 from the older iOS/Android V4 offering. |

## Official Apple sources

| ID | Source | What it supports |
|---|---|---|
| A1 | [External Accessory](https://developer.apple.com/documentation/externalaccessory/) | Manufacturer-supported accessory communication and third-party access requirements. |
| A2 | [USBDriverKit](https://developer.apple.com/documentation/usbdriverkit) and [Creating drivers for iPadOS](https://developer.apple.com/documentation/driverkit/creating-drivers-for-ipados) | Mac and M-series iPad support; not an iPhone transport solution. |
| A3 | [Apple DTS response: custom USB device on iPhone](https://developer.apple.com/forums/thread/802640) | Distinguishes External Accessory streams from raw USB; states that general raw USB interface access is unavailable on iOS. |

## Community research leads

| ID | Pinned source | License inspected | Use and limit |
|---|---|---|---|
| C1 | [lslv1243/neo-control README](https://github.com/lslv1243/neo-control/blob/99d5550bc01a59085c9f65057000b6f4d7005cbc/README.md), `99d5550bc01a59085c9f65057000b6f4d7005cbc` | [MIT](https://github.com/lslv1243/neo-control/blob/99d5550bc01a59085c9f65057000b6f4d7005cbc/LICENSE) | Direct Swift Neo research; no Mini 4 Pro claim. Review provenance before any reuse. |
| C2 | [andreapianidev/DJI-FCC-Unlock-iOS README](https://github.com/andreapianidev/DJI-FCC-Unlock-iOS/blob/000c3325acd556d71da589d2db6c271f0ee6c03d/README.md), `000c3325acd556d71da589d2db6c271f0ee6c03d` | [PolyForm Noncommercial 1.0.0](https://github.com/andreapianidev/DJI-FCC-Unlock-iOS/blob/000c3325acd556d71da589d2db6c271f0ee6c03d/LICENSE) | Transport observation only. Source-available noncommercial code is not imported into this permissive project. Radio/altitude changes are out of scope. |
| C3 | [C2 issue #4](https://github.com/andreapianidev/DJI-FCC-Unlock-iOS/issues/4), checked open on 2026-11-02 | Issue discussion is a reference, not a code dependency | Reported DJI Fly warm-start dependency; issue content is mutable. |
| C4 | [samuelsadok/dji_protocol mobile USB notes](https://github.com/samuelsadok/dji_protocol/blob/50c71b65fdb6825783f724e5cd3c1f09c2aa88ce/usb_mobile_protocol.md), `50c71b65fdb6825783f724e5cd3c1f09c2aa88ce` | No LICENSE file found in the inspected tree; GitHub metadata returned no license | Reference only. Do not copy its implementation or documentation without a suitable permission basis. Device observations do not establish our target combination. |
| C5 | [shinyquagsire23/Klepton README](https://github.com/shinyquagsire23/Klepton/blob/1fe7e6caf6bb8bc90c1a5e61d5b9bfc6e110fa32/README.md), `1fe7e6caf6bb8bc90c1a5e61d5b9bfc6e110fa32` | [MIT](https://github.com/shinyquagsire23/Klepton/blob/1fe7e6caf6bb8bc90c1a5e61d5b9bfc6e110fa32/LICENSE) | Native-library compatibility inspiration. Its Java-thin macOS/visionOS results do not validate DJI MSDK or iPhone support. |

The user-supplied [brainstorm discussion](https://chatgpt.com/share/6ae91470-a894-83e9-b9c8-56fd67b81f81?ogimg=plain) supplied leads. It is not a technical authority; the source files above were checked directly. No text from that conversation is copied here.

## How to add a source

Record owner, exact URL, commit/tag or retrieval date, license, the narrow claim it supports and its limitations. Separate vendor documentation, upstream author's report and our own reproduced evidence. Pin implementation dependencies independently, including any transitive licenses. Do not substitute a repository's public visibility for permission to copy its contents.

Repository identities were resolved through GitHub's public repository and commit APIs, with license files and relevant READMEs inspected directly. Web pages and issues can change; recheck before expanding a claim. No project hardware validation is implied by this research pass.
