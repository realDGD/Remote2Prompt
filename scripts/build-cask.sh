#!/bin/bash
# Runs inside the downloaded source, before Homebrew moves the app.
set -euo pipefail
if [[ $# -ne 3 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! "$2" =~ ^[0-9a-f]{40}$ || ! "$3" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Usage: build-cask.sh VERSION COMMIT SHA256" >&2
    exit 2
fi
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
[[ "$(cat "$repo_dir/VERSION")" == "$1" ]] || { echo "Cask/source version mismatch" >&2; exit 1; }
export DEVELOPER_DIR=/Library/Developer/CommandLineTools
export REMOTE2PROMPT_HOMEBREW_BUILD=1
export CODE_SIGN_IDENTITY=-
export REMOTE2PROMPT_STABLE_ADHOC_IDENTITY=1
export CONFIGURATION=release
unset SDKROOT
"$repo_dir/scripts/test.sh"
"$repo_dir/scripts/build-app.sh"
app="$repo_dir/dist/Remote2Prompt.app"
stamp="$app/Contents/Resources/HomebrewSource.plist"
/usr/bin/plutil -create xml1 "$stamp"
/usr/libexec/PlistBuddy -c "Add :version string $1" "$stamp"
/usr/libexec/PlistBuddy -c "Add :commit string $2" "$stamp"
/usr/libexec/PlistBuddy -c "Add :sha256 string $3" "$stamp"
/usr/libexec/PlistBuddy -c "Add :builder string clt-source-cask" "$stamp"
/usr/libexec/PlistBuddy -c "Add :signingPolicy string identifier-only-adhoc-v1" "$stamp"
"$repo_dir/scripts/sign-app.sh" "$app"
"$repo_dir/scripts/verify-app.sh" "$app"
