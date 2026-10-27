#!/bin/bash
set -euo pipefail
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_dir/scripts/toolchain.sh"
configuration="${CONFIGURATION:-release}"
case "$configuration" in debug|release) ;; *) echo "CONFIGURATION must be debug or release" >&2; exit 1 ;; esac
destination="${1:-$repo_dir/dist/Remote2Prompt.app}"
if [[ "$destination" != /* || "$destination" != */Remote2Prompt.app || -L "$destination" ]]; then
    echo "Output must be an absolute, non-symlink path ending in /Remote2Prompt.app" >&2
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
r2p_swiftpm build --configuration "$configuration" --product Remote2Prompt
binary_dir="$(r2p_swiftpm build --configuration "$configuration" --show-bin-path)"
mkdir -p "$(dirname "$destination")"
stage_dir="$(mktemp -d "$(dirname "$destination")/.remote2prompt-build.XXXXXX")"
trap 'rm -rf "$stage_dir"' EXIT
app_dir="$stage_dir/Remote2Prompt.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/Remote2Prompt" "$app_dir/Contents/MacOS/Remote2Prompt"
cp "$repo_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
version="$(cat "$repo_dir/VERSION")"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must contain a numeric major.minor.patch version" >&2
    exit 1
fi
/usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $version" "$app_dir/Contents/Info.plist"
printf 'APPL????' > "$app_dir/Contents/PkgInfo"
chmod 755 "$app_dir/Contents/MacOS/Remote2Prompt"
/usr/bin/codesign --force --sign - --timestamp=none "$app_dir"
/usr/bin/codesign --verify --deep --strict "$app_dir"
if [[ -e "$destination" ]]; then rm -rf "$destination"; fi
mv "$app_dir" "$destination"
echo "Built $destination ($DEVELOPER_DIR)"
