#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
build="$root/build"
profile="${MACFACE_PROVISIONING_PROFILE:-}"
identity="${MACFACE_SIGN_IDENTITY:-}"

if [[ -n "$profile" || -n "$identity" ]]; then
    if [[ ! -f "$profile" || -z "$identity" || "$identity" == - ]]; then
        printf '%s\n' 'Set MACFACE_PROVISIONING_PROFILE to a macOS development profile and MACFACE_SIGN_IDENTITY to its Apple Development signing identity.' >&2
        exit 1
    fi

    signing_files="$(mktemp -d "${TMPDIR:-/tmp}/macface-signing.XXXXXX")"
    trap 'for file in "$signing_files/profile.plist" "$signing_files/entitlements.plist"; do if [[ -f "$file" ]]; then unlink "$file"; fi; done; rmdir "$signing_files"' EXIT
    security cms -D -i "$profile" -o "$signing_files/profile.plist"
    read_profile() {
        /usr/libexec/PlistBuddy -c "Print :Entitlements:$1" "$signing_files/profile.plist"
    }
    app_id="$(read_profile com.apple.application-identifier)"
    team_id="$(read_profile com.apple.developer.team-identifier)"
    bundle_id="${app_id#*.}"
    if [[ ! "$app_id" =~ ^[A-Z0-9]{10}\.[a-zA-Z0-9.-]+$ || ! "$team_id" =~ ^[A-Z0-9]{10}$ ]] ||
        [[ "$(read_profile com.apple.developer.applesignin:0)" != Default ]]; then
        printf '%s\n' 'The macOS development profile must authorize a specific App ID and Sign in with Apple.' >&2
        exit 1
    fi

    entitlements="$signing_files/entitlements.plist"
    plutil -create xml1 "$entitlements"
    plutil -insert 'com\.apple\.application-identifier' -string "$app_id" "$entitlements"
    plutil -insert 'com\.apple\.developer\.team-identifier' -string "$team_id" "$entitlements"
    plutil -insert 'com\.apple\.developer\.applesignin' -xml '<array><string>Default</string></array>' "$entitlements"
    app="$build/apple-login/Mac Face.app"
else
    app="$build/apple-login-preview/Mac Face.app"
    bundle_id=local.macface.app.apple-login-preview
fi

mkdir -p "$app/Contents/MacOS"
cp "$root/Sources/Info.plist" "$app/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$bundle_id" "$app/Contents/Info.plist"
xcrun swiftc -target arm64-apple-macosx14.0 -O -parse-as-library "$root"/Sources/*.swift -o "$app/Contents/MacOS/MacFace"
if [[ -n "$profile" ]]; then
    cp "$profile" "$app/Contents/embedded.provisionprofile"
    codesign --force --sign "$identity" --timestamp=none --entitlements "$entitlements" "$app"
    codesign --verify --strict -R="anchor apple generic and certificate leaf[subject.OU] = \"$team_id\"" "$app"
else
    codesign --force --sign - "$app"
    codesign --verify --strict "$app"
fi
printf '%s\n' "$app"
