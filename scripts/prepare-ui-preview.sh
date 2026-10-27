#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
preview="$repo_dir/.build/ui-preview/Remote2Prompt.app"
if /bin/ps -axo comm= | /usr/bin/awk -v target="$preview/Contents/MacOS/Remote2Prompt" '$0 == target { found = 1 } END { exit !found }'; then
    echo "Quit the interface preview before rebuilding it." >&2
    exit 1
fi
if [[ -e "$preview" ]]; then
    existing_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$preview/Contents/Info.plist")"
    if [[ "$existing_id" != "dev.remote2prompt.ui-preview" ]]; then
        echo "Refusing to replace an unrecognized preview bundle." >&2
        exit 1
    fi
    rm -rf "$preview"
fi
"$repo_dir/scripts/build-app.sh" "$preview"
/usr/libexec/PlistBuddy -c 'Set CFBundleIdentifier dev.remote2prompt.ui-preview' "$preview/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleName Remote2Prompt Preview' "$preview/Contents/Info.plist"
/usr/bin/codesign --force --sign - --timestamp=none "$preview"
/usr/bin/codesign --verify --deep --strict "$preview"
echo "Interface preview: $preview"
