#!/bin/bash
# Read-only installed-Cask checks; no UI or device adapters.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -eq 0 ]]; then
    values="$(brew info --json=v2 --cask realdgd/voiremote/voiremote | /usr/bin/ruby -rjson -e '
      c = JSON.parse(STDIN.read).fetch("casks").first
      commit = c.fetch("url").match(%r{\Ahttps://github.com/realDGD/VoiRemote/archive/([0-9a-f]{40})\.tar\.gz\z})
      abort "Cask does not use a fixed public source archive" unless commit
      puts [c.fetch("version"), commit[1], c.fetch("sha256")].join(" ")
    ')"
    read -r release_version source_commit archive_sha <<< "$values"
    set -- "$release_version" "$source_commit" "$archive_sha"
fi
if [[ $# -lt 3 || $# -gt 4 || ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ || ! "$2" =~ ^[0-9a-f]{40}$ || ! "$3" =~ ^[0-9a-f]{64}$ ]]; then
    echo "Usage: verify-homebrew-install.sh VERSION COMMIT SHA256 [APPDIR]" >&2
    exit 2
fi
app="${4:-/Applications}/VoiRemote.app"
[[ -d "$app" && ! -L "$app" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")" == dev.voiremote.app ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$1" ]]
stamp="$app/Contents/Resources/HomebrewSource.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print version' "$stamp")" == "$1" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print commit' "$stamp")" == "$2" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print sha256' "$stamp")" == "$3" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print builder' "$stamp")" == clt-source-cask ]]
/usr/bin/codesign --verify --deep --strict "$app"
policy="$(/usr/libexec/PlistBuddy -c 'Print signingPolicy' "$stamp" 2>/dev/null || true)"
if [[ -n "$policy" ]]; then
    "$repo_dir/scripts/verify-signing-identity.sh" "$app" "$policy"
else
    echo "Legacy source Cask: no fixed signing policy declared; stable update identity is not verified."
fi
"$app/Contents/MacOS/VoiRemote" --self-check
[[ "$(voiremote --version)" == "VoiRemote $1" ]]
if brew list --formula voiremote >/dev/null 2>&1 || brew list --cask voiremote-app >/dev/null 2>&1; then
    echo "Legacy Formula/Cask is still installed" >&2; exit 1
fi
caskroot="$(brew --caskroom voiremote)/$1"
[[ -d "$caskroot" ]]
[[ -z "$(/usr/bin/find "$caskroot" -type d \( -name '*.app' -o -name .build \) -print -quit)" ]]
[[ "$(/usr/bin/find "$caskroot" -type l -name VoiRemote.app | /usr/bin/wc -l | /usr/bin/tr -d ' ')" == 1 ]]
echo "Single source Cask verified: $1; source identity and signature match; one real app; build cache removed; no legacy package"
