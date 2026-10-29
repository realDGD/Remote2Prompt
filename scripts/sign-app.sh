#!/bin/bash
# One signing entry point, including re-signing after Homebrew source metadata.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -ne 1 || "$1" != /* || "$1" != */Remote2Prompt.app || -L "$1" ]]; then
    echo "Usage: sign-app.sh /absolute/path/Remote2Prompt.app" >&2
    exit 2
fi
app="$1"
identity="${CODE_SIGN_IDENTITY:--}"
stable="${REMOTE2PROMPT_STABLE_ADHOC_IDENTITY:-0}"
case "$stable" in 0|1) ;; *) echo "REMOTE2PROMPT_STABLE_ADHOC_IDENTITY must be 0 or 1" >&2; exit 2 ;; esac
if [[ "$stable" == 1 && "$identity" != - ]]; then
    echo "Stable ad-hoc mode cannot be combined with a certificate identity" >&2
    exit 2
fi
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")" == dev.remote2prompt.app ]]
if /bin/ps -axo comm= | /usr/bin/awk -v target="$app/Contents/MacOS/Remote2Prompt" '$0 == target { found = 1 } END { exit !found }'; then
    echo "Quit the app before changing its signature." >&2
    exit 1
fi
arguments=(--force --sign "$identity" --timestamp=none)
if [[ "$stable" == 1 ]]; then
    # User-selected certificate-free identity: it does not authenticate the signer.
    arguments+=(--requirements '=designated => identifier "dev.remote2prompt.app"')
fi
/usr/bin/codesign "${arguments[@]}" "$app"
if [[ "$stable" == 1 ]]; then
    "$repo_dir/scripts/verify-signing-identity.sh" "$app" identifier-only-adhoc-v1
elif [[ "$identity" == - ]]; then
    "$repo_dir/scripts/verify-signing-identity.sh" "$app" hash-bound-adhoc-v1
else
    /usr/bin/codesign --verify --deep --strict "$app"
fi
