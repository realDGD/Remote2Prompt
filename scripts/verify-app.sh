#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_dir/scripts/toolchain.sh"
app_dir="${1:-$repo_dir/dist/Remote2Prompt.app}"
/usr/bin/plutil -lint "$app_dir/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app_dir/Contents/Info.plist")" == "dev.remote2prompt.app" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$app_dir/Contents/Info.plist")" == "14.0" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_dir/Contents/Info.plist")" == "$(cat "$repo_dir/VERSION")" ]]
[[ -x "$app_dir/Contents/MacOS/Remote2Prompt" ]]
[[ -s "$app_dir/Contents/Resources/AppIcon.icns" ]]
minimum_system_version="$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$app_dir/Contents/Info.plist")"
sdk_version="$(/usr/bin/xcrun --sdk macosx --show-sdk-version)"
if ! /usr/bin/otool -l "$app_dir/Contents/MacOS/Remote2Prompt" | /usr/bin/awk \
    -v expected_min="$minimum_system_version" -v expected_sdk="$sdk_version" '
    function normalized(version) { sub(/(\.0)+$/, "", version); return version }
    $1 == "cmd" { build = ($2 == "LC_BUILD_VERSION") }
    build && $1 == "platform" { if ($2 != 1) bad = 1; platforms++ }
    build && $1 == "minos" { if (normalized($2) != normalized(expected_min)) bad = 1; minimums++ }
    build && $1 == "sdk" { if (normalized($2) != normalized(expected_sdk)) bad = 1; sdks++ }
    END { if (bad || !sdks || minimums != sdks || platforms != sdks) exit 1 }
'; then
    echo "Mach-O metadata mismatch: expected macOS $minimum_system_version minimum, SDK $sdk_version from the selected CLT" >&2
    exit 1
fi
echo "Mach-O metadata verified: macOS $minimum_system_version minimum, SDK $sdk_version"
/usr/bin/codesign --verify --deep --strict "$app_dir"
stamp="$app_dir/Contents/Resources/HomebrewSource.plist"
if [[ -f "$stamp" ]]; then
    policy="$(/usr/libexec/PlistBuddy -c 'Print signingPolicy' "$stamp" 2>/dev/null || true)"
    if [[ -n "$policy" ]]; then
        "$repo_dir/scripts/verify-signing-identity.sh" "$app_dir" "$policy"
    fi
fi
"$app_dir/Contents/MacOS/Remote2Prompt" --version
"$app_dir/Contents/MacOS/Remote2Prompt" --self-check
