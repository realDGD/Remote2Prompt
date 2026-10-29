#!/bin/bash
# Offline bundle-copy experiment. Never launches apps, requests TCC or writes grants.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
source_app="${1:-$repo_dir/dist/Remote2Prompt.app}"
[[ -d "$source_app" ]]
mkdir -p "$repo_dir/.build"
temporary="$(mktemp -d "$repo_dir/.build/signing-check.XXXXXX")"
trap 'rm -rf "$temporary"' EXIT
export CODE_SIGN_IDENTITY=-
first="$temporary/first version/Remote2Prompt.app"
second="$temporary/second version/Remote2Prompt.app"
mkdir -p "$(dirname "$first")" "$(dirname "$second")"
/usr/bin/ditto "$source_app" "$first"
reject() {
    if "$@" > "$temporary/expected-rejection.log" 2>&1; then
        echo "Expected command to reject the bundle or signing options" >&2
        exit 1
    fi
}
code_hash() {
    /usr/bin/codesign --display --verbose=3 "$1" 2>&1 | /usr/bin/sed -n 's/^CDHash=//p'
}
REMOTE2PROMPT_STABLE_ADHOC_IDENTITY=0 "$repo_dir/scripts/sign-app.sh" "$first"
old_hash="$(code_hash "$first")"
[[ -n "$old_hash" ]]
reject "$repo_dir/scripts/verify-signing-identity.sh" "$first" identifier-only-adhoc-v1
/usr/bin/ditto "$first" "$second"
/usr/libexec/PlistBuddy -c 'Set CFBundleVersion 9001' "$second/Contents/Info.plist"
REMOTE2PROMPT_STABLE_ADHOC_IDENTITY=0 "$repo_dir/scripts/sign-app.sh" "$second"
reject /usr/bin/codesign --verify --test-requirement "=cdhash H\"$old_hash\"" "$second"
echo "PASS default hash identity rejects an updated version"

REMOTE2PROMPT_STABLE_ADHOC_IDENTITY=1 "$repo_dir/scripts/sign-app.sh" "$first"
first_hash="$(code_hash "$first")"
# Re-sign the second version after adding the same kind of sealed source stamp as Cask.
stamp="$second/Contents/Resources/HomebrewSource.plist"
rm -f "$stamp"
/usr/bin/plutil -create xml1 "$stamp"
/usr/libexec/PlistBuddy -c 'Add :signingPolicy string identifier-only-adhoc-v1' "$stamp"
REMOTE2PROMPT_STABLE_ADHOC_IDENTITY=1 "$repo_dir/scripts/sign-app.sh" "$second"
[[ "$first_hash" != "$(code_hash "$second")" ]]
for app in "$first" "$second"; do
    /usr/bin/codesign --verify --strict --test-requirement '=identifier "dev.remote2prompt.app"' "$app"
done
reject "$repo_dir/scripts/verify-signing-identity.sh" "$second" hash-bound-adhoc-v1
echo "PASS different code hashes retain the exact explicit identity after source stamping"

reject env REMOTE2PROMPT_STABLE_ADHOC_IDENTITY=invalid "$repo_dir/scripts/sign-app.sh" "$first"
reject env REMOTE2PROMPT_STABLE_ADHOC_IDENTITY=1 CODE_SIGN_IDENTITY=nonexistent-test-identity "$repo_dir/scripts/sign-app.sh" "$first"
"$repo_dir/scripts/verify-signing-identity.sh" "$first" identifier-only-adhoc-v1
echo "PASS invalid signing options reject before changing an existing signature"

/usr/libexec/PlistBuddy -c 'Set CFBundleIdentifier dev.remote2prompt.signing-test-other' "$second/Contents/Info.plist"
/usr/bin/codesign --force --sign - --timestamp=none --identifier dev.remote2prompt.signing-test-other \
    --requirements '=designated => identifier "dev.remote2prompt.signing-test-other"' "$second"
reject /usr/bin/codesign --verify --test-requirement '=identifier "dev.remote2prompt.app"' "$second"
reject env REMOTE2PROMPT_STABLE_ADHOC_IDENTITY=1 "$repo_dir/scripts/sign-app.sh" "$second"
echo "PASS another application identifier is rejected"

/usr/libexec/PlistBuddy -c 'Set CFBundleVersion 9002' "$first/Contents/Info.plist"
reject "$repo_dir/scripts/verify-signing-identity.sh" "$first" identifier-only-adhoc-v1
echo "PASS modified sealed content fails strict signature verification"
echo "Offline signing checks passed; live TCC persistence and Gatekeeper approval are not tested."
