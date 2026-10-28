#!/bin/bash
# Read-only installed-Cask checks; no UI or device adapters.
set -euo pipefail
if [[ $# -lt 3 || $# -gt 4 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! "$2" =~ ^[0-9a-f]{40}$ || ! "$3" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Usage: verify-homebrew-install.sh VERSION COMMIT SHA256 [APPDIR]" >&2
    exit 2
fi
app="${4:-/Applications}/Remote2Prompt.app"
[[ -d "$app" && ! -L "$app" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")" == dev.remote2prompt.app ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$1" ]]
stamp="$app/Contents/Resources/HomebrewSource.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print version' "$stamp")" == "$1" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print commit' "$stamp")" == "$2" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print sha256' "$stamp")" == "$3" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print builder' "$stamp")" == clt-source-cask ]]
/usr/bin/codesign --verify --deep --strict "$app"
"$app/Contents/MacOS/Remote2Prompt" --self-check
[[ "$(remote2prompt --version)" == "Remote2Prompt $1" ]]
if brew list --formula remote2prompt >/dev/null 2>&1 || brew list --cask remote2prompt-app >/dev/null 2>&1; then
    echo "Legacy Formula/Cask is still installed" >&2; exit 1
fi
caskroot="$(brew --caskroom remote2prompt)/$1"
[[ -d "$caskroot" ]]
[[ -z "$(/usr/bin/find "$caskroot" -type d \( -name '*.app' -o -name .build \) -print -quit)" ]]
[[ "$(/usr/bin/find "$caskroot" -type l -name Remote2Prompt.app | /usr/bin/wc -l | /usr/bin/tr -d ' ')" == 1 ]]
echo "Single source Cask verified: $1; source identity and signature match; one real app; build cache removed; no legacy package"
