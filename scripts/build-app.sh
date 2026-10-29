#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_dir/scripts/toolchain.sh"
configuration="${CONFIGURATION:-release}"
case "$configuration" in debug|release) ;; *) echo "CONFIGURATION must be debug or release" >&2; exit 1 ;; esac
signing_identity="${CODE_SIGN_IDENTITY:--}"
stable_adhoc="${REMOTE2PROMPT_STABLE_ADHOC_IDENTITY:-0}"
case "$stable_adhoc" in 0|1) ;; *) echo "REMOTE2PROMPT_STABLE_ADHOC_IDENTITY must be 0 or 1" >&2; exit 1 ;; esac
if [[ "$stable_adhoc" == "1" && "$signing_identity" != "-" ]]; then
    echo "Stable ad-hoc mode cannot be combined with a certificate identity" >&2
    exit 1
fi
destination="${1:-$repo_dir/dist/Remote2Prompt.app}"
if [[ "$destination" != /* || "$destination" != */Remote2Prompt.app || -L "$destination" ]]; then
    echo "Output must be an absolute, non-symlink path ending in /Remote2Prompt.app" >&2
    exit 1
fi
if /bin/ps -axo comm= | /usr/bin/awk -v target="$destination/Contents/MacOS/Remote2Prompt" '$0 == target { found = 1 } END { exit !found }'; then
    echo "Remote2Prompt is running from $destination. Quit it before rebuilding so the running code and privacy authorization stay consistent." >&2
    exit 1
fi
if [[ -e "$destination" ]]; then
    existing_id="$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$destination/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "$existing_id" != "dev.remote2prompt.app" ]]; then
        echo "Refusing to replace an unrecognized app at $destination" >&2
        exit 1
    fi
fi
cd "$repo_dir"
# Swift Build can stamp the deployment target as the linked SDK (swift-build#1887).
# Preserve macOS 14 support while letting AppKit use the actual SDK's native chrome.
sdk_version="$(/usr/bin/xcrun --sdk macosx --show-sdk-version)"
minimum_system_version="$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' "$repo_dir/Resources/Info.plist")"
r2p_swiftpm build --configuration "$configuration" --product Remote2Prompt \
    -Xlinker -platform_version -Xlinker macos \
    -Xlinker "$minimum_system_version" -Xlinker "$sdk_version"
binary_dir="$(r2p_swiftpm build --configuration "$configuration" --show-bin-path)"
mkdir -p "$(dirname "$destination")"
stage_dir="$(mktemp -d "$(dirname "$destination")/.remote2prompt-build.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
app_dir="$stage_dir/Remote2Prompt.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/Remote2Prompt" "$app_dir/Contents/MacOS/Remote2Prompt"
cp "$repo_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
/usr/bin/xcrun swift -module-cache-path "$repo_dir/.build/icon-module-cache" "$repo_dir/scripts/build-icon.swift" "$stage_dir/AppIcon.iconset"
/usr/bin/iconutil --convert icns "$stage_dir/AppIcon.iconset" --output "$app_dir/Contents/Resources/AppIcon.icns"
version="$(cat "$repo_dir/VERSION")"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must contain a numeric major.minor.patch version" >&2
    exit 1
fi
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $version" "$app_dir/Contents/Info.plist"
printf 'APPL????' > "$app_dir/Contents/PkgInfo"
chmod 755 "$app_dir/Contents/MacOS/Remote2Prompt"
"$repo_dir/scripts/sign-app.sh" "$app_dir"
if [[ -e "$destination" ]]; then rm -rf "$destination"; fi
mv "$app_dir" "$destination"
echo "Built $destination ($DEVELOPER_DIR)"
