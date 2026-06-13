#!/usr/bin/env bash
#
# Cross-platform build & pack pipeline for the Stream Deck VS Code plugin.
#
# Produces two .streamDeckPlugin artifacts matching upstream naming:
#   - com.nicollasr.streamdeckvsc.streamDeckPlugin      (Windows, win-x64)
#   - com.nicollasr.streamdeckvsc.mac.streamDeckPlugin  (macOS, osx-arm64 by default,
#                                                        universal arm64+x64 if BUILD_UNIVERSAL=1)
#
# Each bundle is self-contained (the user does NOT need a .NET runtime installed).
# The macOS executable is ad-hoc codesigned so Gatekeeper does not kill the
# unsigned arm64 binary.
#
# Requirements (all available on macOS, no Rosetta needed):
#   - dotnet SDK (8.0+; the 10.x SDK can build net8.0)
#   - node / npx (for Elgato's official CLI: npx @elgato/cli)
#   - codesign, lipo, file (part of macOS / Xcode command line tools)
#
# Usage:
#   ./build.sh                 # build win-x64 + osx-arm64
#   BUILD_UNIVERSAL=1 ./build.sh  # also lipo osx-arm64 + osx-x64 into a universal mac binary

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$ROOT/StreamDeckVSC/StreamDeckVSC.csproj"
SRC="$ROOT/StreamDeckVSC"
ID="com.nicollasr.streamdeckvsc"
STAGE="$ROOT/build"
OUT="$ROOT/dist"

# net8.0 self-contained builds need the roll-forward hint when only the .NET 10
# SDK/runtime is installed on the build machine.
export DOTNET_ROLL_FORWARD="${DOTNET_ROLL_FORWARD:-LatestMajor}"

rm -rf "$STAGE" "$OUT"
mkdir -p "$STAGE" "$OUT"

# Copy the static plugin assets (manifest, images, property inspector) into a
# staged .sdPlugin directory.
copy_assets() {
  local bundle="$1"
  cp "$SRC/manifest.json" "$bundle/manifest.json"
  cp -R "$SRC/Images" "$bundle/Images"
  cp -R "$SRC/PropertyInspector" "$bundle/PropertyInspector"
}

# Patch the manifest OS array + CodePath in place for the target platform.
# $1 = bundle dir, $2 = platform (windows|mac), $3 = minimum OS version, $4 = CodePath
patch_manifest() {
  local bundle="$1" platform="$2" minver="$3" codepath="$4"
  node -e '
    const fs = require("fs");
    const [file, platform, minver, codepath] = process.argv.slice(1);
    const m = JSON.parse(fs.readFileSync(file, "utf8"));
    m.OS = [{ Platform: platform, MinimumVersion: minver }];
    m.CodePath = codepath;
    fs.writeFileSync(file, JSON.stringify(m, null, 2) + "\n");
  ' "$bundle/manifest.json" "$platform" "$minver" "$codepath"
}

# Publish a self-contained build for a single RID into the given output dir.
publish() {
  local rid="$1" outdir="$2"
  dotnet publish "$PROJECT" \
    -c Release \
    -r "$rid" \
    --self-contained true \
    -o "$outdir"
}

pack() {
  local bundle="$1" outname="$2"
  # Pack into a per-call temp dir so the win/mac bundles (which share the same
  # basename, hence the same produced filename) don't clobber each other.
  local tmp
  tmp="$(mktemp -d)"
  npx --yes @elgato/cli@latest pack "$bundle" -o "$tmp" --force --no-update-check
  local produced="$tmp/$(basename "${bundle%.sdPlugin}").streamDeckPlugin"
  mv "$produced" "$OUT/$outname"
  rm -rf "$tmp"
}

# ----------------------------------------------------------------------------
# Windows (win-x64)
# ----------------------------------------------------------------------------
echo "==> Building Windows (win-x64)"
WIN_BUNDLE="$STAGE/$ID.sdPlugin"
mkdir -p "$WIN_BUNDLE"
publish "win-x64" "$WIN_BUNDLE"
copy_assets "$WIN_BUNDLE"
patch_manifest "$WIN_BUNDLE" "windows" "10" "$ID.exe"
npx --yes @elgato/cli@latest validate "$WIN_BUNDLE" --no-update-check
pack "$WIN_BUNDLE" "$ID.streamDeckPlugin"

# ----------------------------------------------------------------------------
# macOS (osx-arm64, optionally universal)
# ----------------------------------------------------------------------------
# NOTE: the macOS bundle directory keeps the canonical "$ID.sdPlugin" name (not
# "$ID.mac.sdPlugin"). The 7.x validator requires the manifest UUID and the
# action UUIDs to match the bundle directory name, and we deliberately keep the
# same UUIDs on every platform (a user only installs the bundle for their OS).
# Only the final .streamDeckPlugin artifact carries the ".mac" suffix, matching
# upstream's two-artifact naming.
echo "==> Building macOS (osx-arm64)"
MAC_BUNDLE="$STAGE/mac/$ID.sdPlugin"
mkdir -p "$MAC_BUNDLE"
publish "osx-arm64" "$MAC_BUNDLE"

if [ "${BUILD_UNIVERSAL:-0}" = "1" ]; then
  echo "==> Building macOS (osx-x64) for universal binary"
  X64_DIR="$STAGE/osx-x64-tmp"
  publish "osx-x64" "$X64_DIR"
  echo "==> Creating universal (arm64 + x64) binary via lipo"
  lipo -create \
    "$MAC_BUNDLE/$ID" \
    "$X64_DIR/$ID" \
    -output "$MAC_BUNDLE/$ID.universal"
  mv "$MAC_BUNDLE/$ID.universal" "$MAC_BUNDLE/$ID"
  rm -rf "$X64_DIR"
fi

copy_assets "$MAC_BUNDLE"
patch_manifest "$MAC_BUNDLE" "mac" "12" "$ID"

# The macOS executable must be executable and ad-hoc codesigned, otherwise
# Gatekeeper kills the unsigned arm64 binary on launch.
chmod +x "$MAC_BUNDLE/$ID"
echo "==> Ad-hoc codesigning macOS executable"
codesign --force --deep --sign - "$MAC_BUNDLE/$ID"

npx --yes @elgato/cli@latest validate "$MAC_BUNDLE" --no-update-check
pack "$MAC_BUNDLE" "$ID.mac.streamDeckPlugin"

# ----------------------------------------------------------------------------
echo ""
echo "==> Done. Artifacts:"
ls -1 "$OUT"
echo ""
echo "macOS executable architecture:"
file "$MAC_BUNDLE/$ID"
