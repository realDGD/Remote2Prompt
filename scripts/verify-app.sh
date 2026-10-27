#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="${1:-$repo_dir/dist/Remote2Prompt.app}"
/usr/bin/plutil -lint "$app_dir/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app_dir/Contents/Info.plist")" == "dev.remote2prompt.app" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$app_dir/Contents/Info.plist")" == "14.0" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app_dir/Contents/Info.plist")" == "$(cat "$repo_dir/VERSION")" ]]
[[ -x "$app_dir/Contents/MacOS/Remote2Prompt" ]]
/usr/bin/codesign --verify --deep --strict "$app_dir"
"$app_dir/Contents/MacOS/Remote2Prompt" --version
"$app_dir/Contents/MacOS/Remote2Prompt" --self-check
