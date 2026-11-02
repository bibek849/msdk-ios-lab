# Third-party boundaries

The MIT license in this repository covers its original code and documentation. No DJI SDK, DJI Fly binary, community implementation or vendor asset is bundled in the initial repository.

DJI's MSDK 5.18.0 sample license distinguishes MIT sample code from the SDK governed by DJI's EULA. Our license does not grant rights to those SDK components, registration services, accessory protocols, trademarks or firmware. The applicable terms for acquired artifacts, intended experiments and publication of SDK test results remain a stage-0 review item. This document records an engineering boundary, not a determination of legal rights.

Community projects in [docs/SOURCES.md](docs/SOURCES.md) are references, not dependencies or proof of compatibility. Different projects have different licenses; a public repository is not necessarily open source or permission to copy. Retain exact revision and permission records before importing any material in a later change.

The GitHub Actions workflow uses the MIT-licensed [actions/checkout](https://github.com/actions/checkout/tree/11bd71901bbe5b1630ceea73d27597364c9af683) action, pinned by commit. The build uses the official Swift toolchain; no third-party Swift packages are required. CI infrastructure is separate from iOS signing and physical hardware execution.
