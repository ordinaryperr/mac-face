#!/bin/bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
identity="${MACFACE_DEVELOPER_ID:-}"
notary_profile="${MACFACE_NOTARY_PROFILE:-}"
suffix=""
if [[ -n "$identity" || -n "$notary_profile" ]]; then
    if [[ ! "$identity" =~ ^[[:xdigit:]]{40}$ || -z "$notary_profile" ]]; then
        printf '%s\n' 'Set MACFACE_DEVELOPER_ID to the Developer ID Application certificate hash and MACFACE_NOTARY_PROFILE to a notarytool keychain profile.' >&2
        exit 1
    fi
    if ! security find-identity -v -p codesigning | awk -v identity="$identity" '
        toupper($2) == toupper(identity) && /"Developer ID Application: / { found = 1 }
        END { exit !found }
    '; then
        printf '%s\n' 'The matching Developer ID Application signing identity is unavailable.' >&2
        exit 1
    fi
    suffix="-notarized"
fi

app="$("$root/Scripts/build.sh")"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
dmg="$(dirname "$app")/Mac-Face-$version-arm64$suffix.dmg"

staging="$(mktemp -d "${TMPDIR:-/tmp}/mac-face-dmg.XXXXXX")"
trap 'rm -r -- "$staging"' EXIT
mkdir "$staging/volume"
ditto "$app" "$staging/volume/Mac Face.app"
ln -s /Applications "$staging/volume/Applications"

if [[ -n "$identity" ]]; then
    codesign --force --sign "$identity" --options runtime --timestamp "$staging/volume/Mac Face.app"
    codesign --verify --strict "$staging/volume/Mac Face.app"
fi

image="$staging/Mac-Face.dmg"
hdiutil create -volname 'Mac Face' -srcfolder "$staging/volume" -fs 'HFS+' -format UDZO "$image"
if [[ -n "$identity" ]]; then
    codesign --sign "$identity" --timestamp "$image"
    xcrun notarytool submit "$image" --keychain-profile "$notary_profile" --wait
    xcrun stapler staple "$image"
    xcrun stapler validate "$image"
    spctl --assess --type open --context context:primary-signature "$image"
fi
hdiutil verify "$image"
mv "$image" "$dmg"
shasum -a 256 "$dmg"
