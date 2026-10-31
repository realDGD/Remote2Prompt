#!/bin/bash
# File-ownership checks with a signed inert CLI fixture; no production app or SM calls.
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd -P)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
mkdir -p "$repo_dir/.build"
temporary="$(mktemp -d "$repo_dir/.build/cask-files.XXXXXX")"
trap 'rm -rf "$temporary"' EXIT
commit=0000000000000000000000000000000000000000
template="$temporary/template/VoiRemote.app"
mkdir -p "$template/Contents/MacOS" "$template/Contents/Resources"
cat > "$temporary/fixture.c" <<'C'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(int argc, char **argv) {
    FILE *log = fopen(getenv("VOI_FIXTURE_LOG"), "a");
    if (!log) return 2;
    fprintf(log, "%s:%s\n", argv[0], argc > 1 ? argv[1] : "");
    fclose(log);
    return argc > 1 && !strcmp(argv[1], "--restore-login-item") && getenv("VOI_FIXTURE_FAIL") ? 3 : 0;
}
C
/usr/bin/xcrun --sdk macosx clang "$temporary/fixture.c" -o "$template/Contents/MacOS/VoiRemote"
cat > "$template/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.voiremote.app</string>
<key>CFBundleExecutable</key><string>VoiRemote</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.0.0</string>
</dict></plist>
PLIST
/usr/bin/plutil -create xml1 "$template/Contents/Resources/HomebrewSource.plist"
/usr/libexec/PlistBuddy -c "Add :commit string $commit" "$template/Contents/Resources/HomebrewSource.plist"
/usr/bin/codesign --sign - --timestamp=none "$template"
export VOI_FIXTURE_LOG="$temporary/hooks.log"
package="$temporary/package with spaces"
mkdir -p "$package/scripts" "$package/dist"
cp "$repo_dir/scripts/"{cask-app-common,install-cask-app,uninstall-cask-app}.sh "$package/scripts/"
printf '0.0.0\n' > "$package/VERSION"
/usr/bin/ditto "$template" "$package/dist/VoiRemote.app"
target="$temporary/Applications with spaces/VoiRemote.app"
install_app() { /bin/bash "$package/scripts/install-cask-app.sh" "$target" "$commit"; }
uninstall_app() { /bin/bash "$package/scripts/uninstall-cask-app.sh" "$target" "$commit"; }
expect_failure() { if "$@" > "$temporary/expected-error.log" 2>&1; then printf 'Expected failure\n' >&2; exit 1; fi; }

install_app
[[ -d "$target" && ! -L "$target" && -L "$package/dist/VoiRemote.app" ]]
[[ "$(readlink "$package/dist/VoiRemote.app")" == "$target" ]]
grep -Fqx "$target/Contents/MacOS/VoiRemote:--restore-login-item" "$VOI_FIXTURE_LOG"
uninstall_app
[[ ! -e "$target" && -d "$package/dist/VoiRemote.app" && ! -L "$package/dist/VoiRemote.app" ]]
grep -Fqx "$target/Contents/MacOS/VoiRemote:--unregister-login-item" "$VOI_FIXTURE_LOG"
# The staged backup is reusable by Homebrew's upgrade rollback.
install_app
[[ -d "$target" && -L "$package/dist/VoiRemote.app" ]]
expect_failure /bin/bash "$package/scripts/uninstall-cask-app.sh" "$target" 1111111111111111111111111111111111111111
[[ -d "$target" && -L "$package/dist/VoiRemote.app" ]]
uninstall_app
mkdir -p "$target"
printf 'protected\n' > "$target/keep"
expect_failure install_app
[[ "$(cat "$target/keep")" == protected && -d "$package/dist/VoiRemote.app" ]]
rm "$target/keep"; rmdir "$target"
ln -s "$template" "$target"
expect_failure install_app
[[ -L "$target" ]]
rm "$target"
# Failed native registration must keep a usable app rather than lose its installation.
VOI_FIXTURE_FAIL=1 install_app > "$temporary/recovery-warning.log" 2>&1
[[ -d "$target" && -L "$package/dist/VoiRemote.app" ]]
grep -q 'recovery remains pending' "$temporary/recovery-warning.log"
uninstall_app
uninstall_app # Already absent is a no-op; the backup must not be overwritten.
[[ -d "$package/dist/VoiRemote.app" && ! -L "$package/dist/VoiRemote.app" ]]
printf 'Cask installer checks passed: placement, alias, backup/restore, ownership refusal, recovery failure and repeated removal (no SM access).\n'
