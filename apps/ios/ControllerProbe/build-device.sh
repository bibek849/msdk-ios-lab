#!/bin/sh
# Builds ControllerProbe for iPhone from the clean, committed tree and prints the
# source and executable identities for the run record. Review it before running.
# It does not install the app or open any accessory.
set -eu
cd "$(dirname "$0")"
root=$(git rev-parse --show-toplevel)
if [ -n "$(git -C "$root" status --porcelain --untracked-files=no)" ]; then
    echo "Refusing to build: commit or restore tracked changes first." >&2
    exit 1
fi
if [ ! -f Config/Local.xcconfig ]; then
    echo "Missing Config/Local.xcconfig: copy Config/Local.xcconfig.example and fill it in privately." >&2
    exit 1
fi
sha=$(git -C "$root" rev-parse HEAD)
out="build/$sha-$(date -u +%Y%m%dT%H%M%SZ)"
xcodebuild -version
xcodebuild -project ControllerProbe.xcodeproj -scheme ControllerProbe -configuration Release \
    -destination 'generic/platform=iOS' -derivedDataPath "$out/DerivedData" \
    -allowProvisioningUpdates PROBE_SOURCE_SHA="$sha" build
app="$out/DerivedData/Build/Products/Release-iphoneos/ControllerProbe.app"
echo "source=$sha"
echo "app=$PWD/$app"
shasum -a 256 "$app/ControllerProbe"
