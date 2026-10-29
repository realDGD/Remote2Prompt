#!/bin/bash
# Strict validity alone does not verify the application's update identity.
set -euo pipefail
if [[ $# -ne 2 ]]; then
    echo "Usage: verify-signing-identity.sh APP identifier-only-adhoc-v1|hash-bound-adhoc-v1" >&2
    exit 2
fi
app="$1"
policy="$2"
case "$policy" in identifier-only-adhoc-v1|hash-bound-adhoc-v1) ;; *) echo "Unknown signing policy" >&2; exit 2 ;; esac
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")" == dev.remote2prompt.app ]]
/usr/bin/codesign --verify --deep --strict "$app"
details="$(/usr/bin/codesign --display --verbose=2 "$app" 2>&1)"
[[ "$details" == *$'\nSignature=adhoc'* ]]
requirement="$(/usr/bin/codesign --display --requirements - "$app" 2>&1 | /usr/bin/sed -n '/^\(# \)\{0,1\}designated => /p')"
if [[ "$policy" == identifier-only-adhoc-v1 ]]; then
    if [[ "$requirement" != 'designated => identifier "dev.remote2prompt.app"' ]]; then
        echo "Expected the explicit identifier-only identity; refusing a different requirement." >&2
        exit 1
    fi
    /usr/bin/codesign --verify --test-requirement '=identifier "dev.remote2prompt.app"' "$app"
elif [[ ! "$requirement" =~ ^\#\ designated\ =\>\ cdhash\ H\"[0-9a-f]+\"$ ]]; then
    echo "Expected the default code-hash identity." >&2
    exit 1
fi
echo "Signing identity verified: $policy"
