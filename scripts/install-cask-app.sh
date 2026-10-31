#!/bin/bash
# Homebrew's supported installer script owns placement and native service integration.
source "$(dirname "${BASH_SOURCE[0]}")/cask-app-common.sh"
[[ ! -e "$app" && ! -L "$app" ]] || fail "Refusing to overwrite an existing application."
owned_app "$staged_app" || fail "The staged app does not match the source receipt or signature."
require_stopped
parent="$(dirname "$app")"
/bin/mkdir -p "$parent"
transaction="$(/usr/bin/mktemp -d "$parent/.VoiRemote-install.XXXXXX")"
prepared="$transaction/VoiRemote.app"
phase=staged
cleanup() {
    local result=$?
    trap - EXIT
    set +e
    if [[ $result -ne 0 ]]; then
        if [[ "$phase" == installed ]] && owned_app "$app"; then
            if own_alias; then /bin/rm "$staged_app"; fi
            if [[ ! -e "$staged_app" && ! -L "$staged_app" ]]; then /bin/mv "$app" "$staged_app"; fi
        elif [[ "$phase" == prepared ]] && owned_app "$prepared"; then
            /bin/mv "$prepared" "$staged_app"
        fi
    fi
    # Keep a bundle for recovery if an interrupted file move could not be reversed.
    if ! /bin/rmdir "$transaction" 2>/dev/null; then
        printf 'Installation recovery files retained at %s\n' "$transaction" >&2
    fi
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
/bin/mv "$staged_app" "$prepared"
phase=prepared
[[ ! -e "$app" && ! -L "$app" ]] || fail "Application destination changed during installation."
/bin/mv "$prepared" "$app"
phase=installed
/bin/ln -s "$app" "$staged_app"
# Run from the final app URL. Installer scripts support the required Mach services.
if ! "$app/Contents/MacOS/VoiRemote" --restore-login-item; then
    printf 'Login-item recovery remains pending; retry in General settings.\n' >&2
fi
