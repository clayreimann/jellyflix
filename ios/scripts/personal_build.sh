#!/usr/bin/env bash
#
# Build (and optionally install) a personally signed iOS build of Jellyflix
# under your own bundle ID, display name and Apple Developer team, without
# leaving any changes in the committed Xcode project.
#
# The Runner target hard-codes the official bundle ID and manual "match"
# signing used by the release pipeline. This script patches those settings in
# a temporary copy-on-write fashion (the original files are backed up and
# restored when the script exits, even on failure), runs the build, and then
# puts everything back.
#
# Usage (from the repository root):
#
#   JELLYFLIX_TEAM_ID=ABCDE12345 \
#   JELLYFLIX_BUNDLE_ID=com.example.jellyflix \
#   JELLYFLIX_DISPLAY_NAME="Jellyflix Beta" \
#     ios/scripts/personal_build.sh [--install [DEVICE]] [-- extra flutter args]
#
# Instead of environment variables you can put the same three variables in
# ios/personal_build.env (git-ignored), which is sourced if it exists.
#
# See docs/ios-personal-build.md for the full walkthrough.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IOS_DIR="$REPO_ROOT/ios"

if [[ -f "$IOS_DIR/personal_build.env" ]]; then
  # shellcheck disable=SC1091
  source "$IOS_DIR/personal_build.env"
fi

INSTALL=0
DEVICE=""
FLUTTER_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install)
      INSTALL=1
      if [[ $# -gt 1 && "$2" != --* ]]; then
        DEVICE="$2"
        shift
      fi
      ;;
    --)
      shift
      FLUTTER_ARGS=("$@")
      break
      ;;
    -h|--help)
      sed -n '2,24p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $1 (use -- before extra flutter arguments)" >&2
      exit 2
      ;;
  esac
  shift
done

: "${JELLYFLIX_TEAM_ID:?Set JELLYFLIX_TEAM_ID to your 10-character Apple team ID}"
: "${JELLYFLIX_BUNDLE_ID:?Set JELLYFLIX_BUNDLE_ID, e.g. com.yourname.jellyflix}"
JELLYFLIX_DISPLAY_NAME="${JELLYFLIX_DISPLAY_NAME:-Jellyflix Beta}"

if [[ "$JELLYFLIX_BUNDLE_ID" == "com.ambark.jellyflix" ]]; then
  echo "Use your own bundle ID. Reusing the App Store ID makes iOS keep the" >&2
  echo "App Store copy, or fail to install, on devices that already have it." >&2
  exit 2
fi

if [[ "$(uname)" != "Darwin" ]]; then
  echo "iOS builds need macOS with Xcode installed." >&2
  exit 1
fi

PBXPROJ="$IOS_DIR/Runner.xcodeproj/project.pbxproj"
INFO_PLIST="$IOS_DIR/Runner/Info.plist"
BACKUP_DIR="$(mktemp -d)"
cp "$PBXPROJ" "$BACKUP_DIR/project.pbxproj"
cp "$INFO_PLIST" "$BACKUP_DIR/Info.plist"

restore() {
  cp "$BACKUP_DIR/project.pbxproj" "$PBXPROJ"
  cp "$BACKUP_DIR/Info.plist" "$INFO_PLIST"
  rm -rf "$BACKUP_DIR"
}
trap restore EXIT

echo "==> Patching signing for $JELLYFLIX_BUNDLE_ID (team $JELLYFLIX_TEAM_ID)"
# Only the Runner project is touched, so the CocoaPods targets keep their own
# bundle IDs. Values are passed through the environment so that perl never
# interprets them.
OLD_ID="com.ambark.jellyflix" NEW_ID="$JELLYFLIX_BUNDLE_ID" TEAM="$JELLYFLIX_TEAM_ID" \
perl -pi -e '
  s/PROVISIONING_PROFILE_SPECIFIER(\[sdk=iphoneos\*\]"?)? = "[^"]*";/PROVISIONING_PROFILE_SPECIFIER$1 = "";/g;
  s/\Q$ENV{OLD_ID}\E/$ENV{NEW_ID}/g;
  s/SENSITIVE_REPLACE_ME/$ENV{TEAM}/g;
  s/CODE_SIGN_STYLE = Manual;/CODE_SIGN_STYLE = Automatic;/g;
  s/("CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]") = "iPhone (Distribution|Developer)";/$1 = "Apple Development";/g;
' "$PBXPROJ"
plutil -replace CFBundleDisplayName -string "$JELLYFLIX_DISPLAY_NAME" "$INFO_PLIST"

cd "$REPO_ROOT"
echo "==> flutter pub get"
flutter pub get
echo "==> Generating Xcode configuration (release)"
flutter build ios --release --config-only "${FLUTTER_ARGS[@]+"${FLUTTER_ARGS[@]}"}"
echo "==> pod install"
(cd "$IOS_DIR" && LANG="${LANG:-en_US.UTF-8}" LC_ALL="${LC_ALL:-en_US.UTF-8}" pod install)

DERIVED_DATA="$REPO_ROOT/build/ios-personal"
echo "==> xcodebuild (signing with automatic provisioning)"
xcodebuild \
  -workspace "$IOS_DIR/Runner.xcworkspace" \
  -scheme Runner \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED_DATA" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Release-iphoneos/Runner.app"
echo
echo "Built: $APP_PATH"

if [[ "$INSTALL" -eq 1 ]]; then
  if [[ -z "$DEVICE" ]]; then
    echo "==> Connected devices:"
    xcrun devicectl list devices
    echo "Re-run with --install <device name or identifier> to pick one." >&2
    exit 0
  fi
  echo "==> Installing on $DEVICE"
  xcrun devicectl device install app --device "$DEVICE" "$APP_PATH"
  xcrun devicectl device process launch --device "$DEVICE" "$JELLYFLIX_BUNDLE_ID" || true
else
  echo "Install with:"
  echo "  xcrun devicectl device install app --device <device> \"$APP_PATH\""
fi
