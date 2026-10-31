#!/bin/bash
# Sourced by build/check commands. Never change the machine-wide xcode-select setting.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Library/Developer/CommandLineTools}"
if [[ ! -d "$DEVELOPER_DIR" ]]; then
    echo "Command Line Tools not found. Run xcode-select --install, then retry." >&2
    exit 1
fi
if ! /usr/bin/xcrun --find swift >/dev/null 2>&1; then
    echo "The selected developer directory has no Swift compiler: $DEVELOPER_DIR" >&2
    exit 1
fi
export SDKROOT="$(/usr/bin/xcrun --sdk macosx --show-sdk-path)"

voi_swiftpm() {
    local operation="$1"
    shift
    if [[ "${VOIREMOTE_HOMEBREW_BUILD:-0}" == "1" ]]; then
        # Homebrew already confines the build; macOS rejects a nested sandbox-exec.
        /usr/bin/xcrun swift "$operation" --disable-sandbox \
            --cache-path "$repo_dir/.build/cache" --config-path "$repo_dir/.build/config" \
            --security-path "$repo_dir/.build/security" "$@"
    else
        /usr/bin/xcrun swift "$operation" "$@"
    fi
}
