#!/bin/bash
# Shared ownership checks for the vendor installer and uninstaller.
set -euo pipefail
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fail() { printf '%s\n' "$1" >&2; exit 1; }
[[ $# -eq 2 && "$1" == /* && "$1" == */VoiRemote.app && "$2" =~ ^[0-9a-f]{40}$ ]] || fail "Expected an absolute VoiRemote.app path and source commit."
[[ "$1" != "$repo_dir"/* ]] || fail "The installed app must be outside its source staging directory."
app="$1"
expected_commit="$2"
staged_app="$repo_dir/dist/VoiRemote.app"
expected_version="$(cat "$repo_dir/VERSION")"

owned_app() {
    local candidate="$1"
    [[ -d "$candidate" && ! -L "$candidate" && -x "$candidate/Contents/MacOS/VoiRemote" ]] &&
    [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$candidate/Contents/Info.plist" 2>/dev/null)" == dev.voiremote.app ]] &&
    [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$candidate/Contents/Info.plist" 2>/dev/null)" == "$expected_version" ]] &&
    [[ "$(/usr/libexec/PlistBuddy -c 'Print commit' "$candidate/Contents/Resources/HomebrewSource.plist" 2>/dev/null)" == "$expected_commit" ]] &&
    /usr/bin/codesign --verify --deep --strict "$candidate" 2>/dev/null
}

own_alias() { [[ -L "$staged_app" && "$(/usr/bin/readlink "$staged_app")" == "$app" ]]; }

require_stopped() {
    if /bin/ps -axo comm= | /usr/bin/grep -Fqx -- "$app/Contents/MacOS/VoiRemote"; then
        fail "Quit VoiRemote before moving its app bundle."
    fi
}
