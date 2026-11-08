#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
app="$root/build/Mac Face.app"
mkdir -p "$app/Contents/MacOS"
cp "$root/Sources/Info.plist" "$app/Contents/Info.plist"
xcrun swiftc -target arm64-apple-macosx14.0 -O -parse-as-library "$root"/Sources/*.swift -o "$app/Contents/MacOS/MacFace"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
printf '%s\n' "$app"
